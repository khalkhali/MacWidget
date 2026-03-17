import SwiftUI
import WidgetKit

@main
struct CPUUsageApp: App {
    @StateObject private var metricsStore = MetricsStore()

    var body: some Scene {
        WindowGroup {
            CPUUsageHostView()
                .environmentObject(metricsStore)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 430, height: 330)
    }
}

private struct CPUUsageHostView: View {
    @EnvironmentObject private var metricsStore: MetricsStore
    @State private var didRequestWidgetReload = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CPUUsageCard(snapshot: metricsStore.snapshot, style: .appPreview)
                .frame(width: 380, height: 230)

            VStack(alignment: .leading, spacing: 8) {
                Text("Widget Ready")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))

                Text("Add “CPU Usage” from Edit Widgets. Refresh timing is handled by WidgetKit and may be throttled by macOS.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Button("Reload Widget") {
                    WidgetCenter.shared.reloadAllTimelines()
                }

                Text("Host app preview")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 430, height: 330, alignment: .topLeading)
        .task {
            guard !didRequestWidgetReload else { return }
            didRequestWidgetReload = true
            WidgetCenter.shared.reloadTimelines(ofKind: "CPUUsageWidget")
        }
    }
}
