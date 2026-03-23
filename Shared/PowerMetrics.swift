import Foundation
import IOKit
import IOKit.pwr_mgt
import SwiftUI

@MainActor
final class PowerMetricsStore: ObservableObject {
    @Published private(set) var snapshot = PowerSnapshot.placeholder

    private let sampler = PowerSampler()
    private var samplingTask: Task<Void, Never>?

    init() {
        samplingTask = Task {
            while !Task.isCancelled {
                snapshot = await sampler.sample()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    deinit {
        samplingTask?.cancel()
    }
}

struct USBPortSnapshot: Sendable, Identifiable {
    let id: Int
    let index: Int
    let isConnected: Bool
    let hasLiveData: Bool
    let advertisedVoltageVolts: Double?
    let advertisedCurrentAmps: Double?
    let activeVoltageVolts: Double?
    let activeCurrentAmps: Double?

    var activePowerWatts: Double? {
        guard let activeVoltageVolts, let activeCurrentAmps else { return nil }
        return activeVoltageVolts * activeCurrentAmps
    }

    var statusLabel: String {
        guard hasLiveData else {
            return "Unavailable"
        }
        if activeVoltageVolts != nil, activeCurrentAmps != nil {
            return "Active"
        }
        return isConnected ? "Connected" : "Idle"
    }

    var electricalSummary: String {
        guard hasLiveData else {
            return "No live data"
        }

        if let activeVoltageVolts, let activeCurrentAmps {
            return "\(activeVoltageVolts.formatted(.number.precision(.fractionLength(1))))V • \(activeCurrentAmps.formatted(.number.precision(.fractionLength(2))))A"
        }

        if let advertisedVoltageVolts, let advertisedCurrentAmps, isConnected {
            return "\(advertisedVoltageVolts.formatted(.number.precision(.fractionLength(1))))V • \(advertisedCurrentAmps.formatted(.number.precision(.fractionLength(2))))A max"
        }

        return "No live contract"
    }
}

struct PowerSnapshot: Sendable {
    let batteryPercent: Int
    let maximumCapacityPercent: Int
    let cycleCount: Int
    let isCharging: Bool
    let isExternalPowerConnected: Bool
    let timeRemainingMinutes: Int?
    let voltageVolts: Double?
    let amperageAmps: Double?
    let powerWatts: Double?
    let temperatureCelsius: Double?
    let usbPorts: [USBPortSnapshot]
    let deviceName: String
    let lastUpdated: Date

    static let placeholder = PowerSnapshot(
        batteryPercent: 92,
        maximumCapacityPercent: 100,
        cycleCount: 13,
        isCharging: false,
        isExternalPowerConnected: false,
        timeRemainingMinutes: 496,
        voltageVolts: 12.7,
        amperageAmps: -0.70,
        powerWatts: 8.9,
        temperatureCelsius: 31.9,
        usbPorts: [
            USBPortSnapshot(id: 0, index: 1, isConnected: true, hasLiveData: true, advertisedVoltageVolts: 5.0, advertisedCurrentAmps: 3.0, activeVoltageVolts: nil, activeCurrentAmps: nil),
            USBPortSnapshot(id: 1, index: 2, isConnected: false, hasLiveData: false, advertisedVoltageVolts: nil, advertisedCurrentAmps: nil, activeVoltageVolts: nil, activeCurrentAmps: nil),
            USBPortSnapshot(id: 2, index: 3, isConnected: false, hasLiveData: false, advertisedVoltageVolts: nil, advertisedCurrentAmps: nil, activeVoltageVolts: nil, activeCurrentAmps: nil),
            USBPortSnapshot(id: 3, index: 4, isConnected: true, hasLiveData: true, advertisedVoltageVolts: 5.0, advertisedCurrentAmps: 1.46, activeVoltageVolts: 5.0, activeCurrentAmps: 1.46)
        ],
        deviceName: "bq40z651",
        lastUpdated: .now
    )

    var batteryFraction: Double {
        min(max(Double(batteryPercent) / 100, 0), 1)
    }

    var healthLabel: String {
        "\(maximumCapacityPercent)%"
    }

    var sourceLabel: String {
        if isCharging {
            return "Charging"
        }
        if isExternalPowerConnected {
            return "AC Power"
        }
        return "Battery Power"
    }

    var timeRemainingLabel: String {
        guard let timeRemainingMinutes, timeRemainingMinutes > 0 else {
            return isCharging ? "Charging" : "No estimate"
        }

        let hours = timeRemainingMinutes / 60
        let minutes = timeRemainingMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }
        return "\(minutes)m left"
    }

    var usbConnectedPortCount: Int {
        usbPorts.filter { $0.hasLiveData && $0.isConnected }.count
    }

    var primaryUSBContractLabel: String {
        if let activePort = usbPorts.first(where: { $0.hasLiveData && $0.activeVoltageVolts != nil && $0.activeCurrentAmps != nil }) {
            return "Port \(activePort.index) • \(activePort.electricalSummary)"
        }

        if let connectedPort = usbPorts.first(where: { $0.hasLiveData && $0.isConnected }) {
            return "Port \(connectedPort.index) • \(connectedPort.electricalSummary)"
        }

        return "Live per-port USB power unavailable"
    }
}

actor PowerSampler {
    func sample() -> PowerSnapshot {
        let properties = readBatteryProperties()
        let percent = intValue(for: "CurrentCapacity", in: properties)
        let maxCapacityPercent = intValue(for: "MaxCapacity", in: properties)
        let cycleCount = intValue(for: "CycleCount", in: properties)
        let isCharging = boolValue(for: "IsCharging", in: properties)
        let externalConnected = boolValue(for: "ExternalConnected", in: properties)
        let voltageMillivolts = intValue(for: "Voltage", in: properties)
        let amperageMilliamps = signedIntValue(for: "Amperage", in: properties) ?? signedIntValue(for: "InstantAmperage", in: properties)
        let voltageVolts = voltageMillivolts > 0 ? Double(voltageMillivolts) / 1000 : nil
        let amperageAmps = amperageMilliamps.map { Double($0) / 1000 }
        let powerWatts: Double? = {
            guard let voltageVolts, let amperageAmps else { return nil }
            return abs(voltageVolts * amperageAmps)
        }()

        let temperatureRaw = intValue(for: "Temperature", in: properties)
        let temperatureCelsius = temperatureRaw > 0 ? (Double(temperatureRaw) / 10) - 273.15 : nil
        let usbPorts = parseUSBPorts(from: properties, allowLivePortContracts: externalConnected || isCharging)

        return PowerSnapshot(
            batteryPercent: percent,
            maximumCapacityPercent: maxCapacityPercent,
            cycleCount: cycleCount,
            isCharging: isCharging,
            isExternalPowerConnected: externalConnected,
            timeRemainingMinutes: optionalPositiveIntValue(for: "TimeRemaining", in: properties),
            voltageVolts: voltageVolts,
            amperageAmps: amperageAmps,
            powerWatts: powerWatts,
            temperatureCelsius: temperatureCelsius,
            usbPorts: usbPorts,
            deviceName: stringValue(for: "DeviceName", in: properties) ?? "Battery",
            lastUpdated: .now
        )
    }

    private func readBatteryProperties() -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }

        var propertiesRef: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &propertiesRef, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS, let properties = propertiesRef?.takeRetainedValue() as? [String: Any] else {
            return [:]
        }
        return properties
    }

    private func parseUSBPorts(from properties: [String: Any], allowLivePortContracts: Bool) -> [USBPortSnapshot] {
        let fedDetails = (properties["FedDetails"] as? [[String: Any]]) ?? []
        let controllerInfo = (properties["PortControllerInfo"] as? [[String: Any]]) ?? []
        let portCount = max(fedDetails.count, controllerInfo.count)

        guard portCount > 0 else { return [] }

        return (0 ..< portCount).map { index in
            let fed = index < fedDetails.count ? fedDetails[index] : [:]
            let controller = index < controllerInfo.count ? controllerInfo[index] : [:]
            let controllerConnected = boolValue(for: "FedExternalConnected", in: fed)

            let pdoList = (controller["PortControllerPortPDO"] as? [NSNumber])?.map(\.uint32Value) ?? []
            let selectedPDO = selectedPDO(for: controller, from: pdoList)
            let advertisedContract = selectedPDO.flatMap(decodeFixedPDO)

            let activeCurrentAmps = decodeRDOCurrent(from: controller["PortControllerActiveContractRdo"])
            let activeVoltageVolts = activeCurrentAmps != nil ? advertisedContract?.voltageVolts : nil

            return USBPortSnapshot(
                id: index,
                index: index + 1,
                isConnected: allowLivePortContracts ? controllerConnected : false,
                hasLiveData: allowLivePortContracts,
                advertisedVoltageVolts: allowLivePortContracts ? advertisedContract?.voltageVolts : nil,
                advertisedCurrentAmps: allowLivePortContracts ? advertisedContract?.currentAmps : nil,
                activeVoltageVolts: allowLivePortContracts ? activeVoltageVolts : nil,
                activeCurrentAmps: allowLivePortContracts ? activeCurrentAmps : nil
            )
        }
    }

    private func selectedPDO(for controller: [String: Any], from pdoList: [UInt32]) -> UInt32? {
        guard !pdoList.isEmpty else { return nil }

        if let rawRdo = controller["PortControllerActiveContractRdo"] as? NSNumber {
            let objectPosition = Int((rawRdo.uint32Value >> 28) & 0x7)
            if objectPosition > 0, objectPosition <= pdoList.count {
                return pdoList[objectPosition - 1]
            }
        }

        return pdoList.first(where: { $0 != 0 })
    }

    private func decodeFixedPDO(_ rawValue: UInt32) -> (voltageVolts: Double, currentAmps: Double)? {
        let supplyType = (rawValue >> 30) & 0x3
        guard supplyType == 0 else { return nil }

        let voltageVolts = Double((rawValue >> 10) & 0x3ff) * 0.05
        let currentAmps = Double(rawValue & 0x3ff) * 0.01
        guard voltageVolts > 0, currentAmps > 0 else { return nil }
        return (voltageVolts, currentAmps)
    }

    private func decodeRDOCurrent(from rawValue: Any?) -> Double? {
        guard let number = rawValue as? NSNumber else { return nil }
        let rawRdo = number.uint32Value
        guard rawRdo != 0 else { return nil }
        let operatingCurrentAmps = Double((rawRdo >> 10) & 0x3ff) * 0.01
        return operatingCurrentAmps > 0 ? operatingCurrentAmps : nil
    }
}

private func intValue(for key: String, in dictionary: [String: Any]) -> Int {
    if let value = dictionary[key] as? NSNumber {
        return value.intValue
    }
    return 0
}

private func optionalPositiveIntValue(for key: String, in dictionary: [String: Any]) -> Int? {
    let value = intValue(for: key, in: dictionary)
    return value > 0 && value != 65_535 ? value : nil
}

private func signedIntValue(for key: String, in dictionary: [String: Any]) -> Int? {
    guard let value = dictionary[key] as? NSNumber else { return nil }
    return Int(Int64(bitPattern: value.uint64Value))
}

private func boolValue(for key: String, in dictionary: [String: Any]) -> Bool {
    if let value = dictionary[key] as? Bool {
        return value
    }
    if let value = dictionary[key] as? NSNumber {
        return value.boolValue
    }
    return false
}

private func stringValue(for key: String, in dictionary: [String: Any]) -> String? {
    dictionary[key] as? String
}
