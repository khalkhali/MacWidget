import SwiftUI
import WidgetKit

@main
struct CPUUsageApp: App {
    @StateObject private var metricsStore = MetricsStore()
    @StateObject private var powerMetricsStore = PowerMetricsStore()

    var body: some Scene {
        WindowGroup {
            CPUUsageHostView()
                .environmentObject(metricsStore)
                .environmentObject(powerMetricsStore)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 820, height: 380)
    }
}

private struct CPUUsageHostView: View {
    @EnvironmentObject private var metricsStore: MetricsStore
    @EnvironmentObject private var powerMetricsStore: PowerMetricsStore
    @State private var didRequestWidgetReload = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                CPUUsageCard(snapshot: metricsStore.snapshot, style: .appPreview)
                    .frame(width: 380, height: 230)

                PowerStatusCard(snapshot: powerMetricsStore.snapshot, familyOverride: .systemMedium)
                    .frame(width: 350, height: 230)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Widgets Ready")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))

                Text("Add the widgets from Edit Widgets under MacWidget. Refresh timing is handled by WidgetKit and may be throttled by macOS.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Button("Reload Widgets") {
                    WidgetCenter.shared.reloadAllTimelines()
                }

                Text("Live host previews")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 820, height: 380, alignment: .topLeading)
        .task {
            guard !didRequestWidgetReload else { return }
            didRequestWidgetReload = true
            WidgetCenter.shared.reloadTimelines(ofKind: "CPUUsageWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "USBPowerWidget")
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                WidgetCenter.shared.reloadTimelines(ofKind: "CPUUsageWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "USBPowerWidget")
            }
        }
    }
}
