import Foundation
import IOKit.pwr_mgt
import SwiftUI

@MainActor
final class MetricsStore: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.placeholder

    private let sampler = MetricSampler()
    private var samplingTask: Task<Void, Never>?

    init() {
        samplingTask = Task {
            while !Task.isCancelled {
                let newSnapshot = await sampler.sample()
                snapshot = newSnapshot
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    deinit {
        samplingTask?.cancel()
    }
}

struct SystemSnapshot: Sendable {
    let cpuUsage: Double
    let userUsage: Double
    let systemUsage: Double
    let busyLogicalCPUs: Int
    let logicalCPUs: Int
    let physicalCPUs: Int
    let systemThreads: Int
    let taskThreads: Int
    let chipName: String
    let thermalState: ProcessInfo.ThermalState
    let thermalWarningLevel: UInt32?
    let lastUpdated: Date

    static let placeholder = SystemSnapshot(
        cpuUsage: 0,
        userUsage: 0,
        systemUsage: 0,
        busyLogicalCPUs: 0,
        logicalCPUs: 0,
        physicalCPUs: 0,
        systemThreads: 0,
        taskThreads: 0,
        chipName: "Loading…",
        thermalState: .nominal,
        thermalWarningLevel: nil,
        lastUpdated: .now
    )

    var busyThreadFraction: Double {
        guard logicalCPUs > 0 else { return 0 }
        return min(1, Double(busyLogicalCPUs) / Double(logicalCPUs))
    }

    var thermalGaugeValue: Double {
        switch thermalState {
        case .nominal:
            return 0.22
        case .fair:
            return 0.48
        case .serious:
            return 0.74
        case .critical:
            return 1.0
        @unknown default:
            return 0.4
        }
    }

    var thermalLabel: String {
        switch thermalState {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }

    var thermalSubtitle: String {
        guard let thermalWarningLevel else {
            return "Pressure"
        }
        return "Level \(thermalWarningLevel)"
    }
}

actor MetricSampler {
    private var previousTicks: [[UInt64]]?

    func sample() -> SystemSnapshot {
        let currentTicks = readCPUTicks()
        let deltaSummary = computeDelta(current: currentTicks, previous: previousTicks)
        previousTicks = currentTicks

        var thermalWarning: UInt32 = 0
        let thermalResult = IOPMGetThermalWarningLevel(&thermalWarning)

        return SystemSnapshot(
            cpuUsage: deltaSummary.cpuUsage,
            userUsage: deltaSummary.userUsage,
            systemUsage: deltaSummary.systemUsage,
            busyLogicalCPUs: deltaSummary.busyLogicalCPUs,
            logicalCPUs: sysctlInt("hw.logicalcpu"),
            physicalCPUs: sysctlInt("hw.physicalcpu"),
            systemThreads: sysctlInt("kern.num_threads"),
            taskThreads: sysctlInt("kern.num_taskthreads"),
            chipName: sysctlString("machdep.cpu.brand_string") ?? "Apple Silicon",
            thermalState: ProcessInfo.processInfo.thermalState,
            thermalWarningLevel: thermalResult == kIOReturnSuccess ? thermalWarning : nil,
            lastUpdated: .now
        )
    }

    private func readCPUTicks() -> [[UInt64]] {
        var cpuCount: natural_t = 0
        var infoCount: mach_msg_type_number_t = 0
        var info: processor_info_array_t?

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &info,
            &infoCount
        )

        guard result == KERN_SUCCESS, let info else {
            return []
        }

        defer {
            let size = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        let stride = Int(CPU_STATE_MAX)
        let values = UnsafeBufferPointer(start: info, count: Int(infoCount))

        return (0 ..< Int(cpuCount)).map { index in
            let offset = index * stride
            return [
                UInt64(values[offset + Int(CPU_STATE_USER)]),
                UInt64(values[offset + Int(CPU_STATE_SYSTEM)]),
                UInt64(values[offset + Int(CPU_STATE_IDLE)]),
                UInt64(values[offset + Int(CPU_STATE_NICE)])
            ]
        }
    }

    private func computeDelta(current: [[UInt64]], previous: [[UInt64]]?) -> DeltaSummary {
        guard let previous, previous.count == current.count else {
            return DeltaSummary(cpuUsage: 0, userUsage: 0, systemUsage: 0, busyLogicalCPUs: 0)
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0
        var busyLogicalCPUs = 0

        for (currentCore, previousCore) in zip(current, previous) {
            let user = currentCore[0] &- previousCore[0]
            let system = currentCore[1] &- previousCore[1]
            let idle = currentCore[2] &- previousCore[2]
            let nice = currentCore[3] &- previousCore[3]
            let total = user + system + idle + nice

            totalUser += user
            totalSystem += system
            totalIdle += idle
            totalNice += nice

            guard total > 0 else { continue }
            let usage = Double(user + system + nice) / Double(total)
            if usage > 0.08 {
                busyLogicalCPUs += 1
            }
        }

        let totalTicks = totalUser + totalSystem + totalIdle + totalNice
        guard totalTicks > 0 else {
            return DeltaSummary(cpuUsage: 0, userUsage: 0, systemUsage: 0, busyLogicalCPUs: busyLogicalCPUs)
        }

        return DeltaSummary(
            cpuUsage: Double(totalUser + totalSystem + totalNice) / Double(totalTicks),
            userUsage: Double(totalUser) / Double(totalTicks),
            systemUsage: Double(totalSystem) / Double(totalTicks),
            busyLogicalCPUs: busyLogicalCPUs
        )
    }
}

private struct DeltaSummary {
    let cpuUsage: Double
    let userUsage: Double
    let systemUsage: Double
    let busyLogicalCPUs: Int
}

private func sysctlInt(_ name: String) -> Int {
    var value: Int32 = 0
    var size = MemoryLayout<Int32>.size
    guard sysctlbyname(name, &value, &size, nil, 0) == 0 else {
        return 0
    }
    return Int(value)
}

private func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
        return nil
    }

    var value = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &value, &size, nil, 0) == 0 else {
        return nil
    }

    let bytes = value.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return String(decoding: bytes, as: UTF8.self)
}
