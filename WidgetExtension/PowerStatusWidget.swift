import SwiftUI
import WidgetKit

struct PowerStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: PowerSnapshot
}

struct PowerStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> PowerStatusEntry {
        PowerStatusEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PowerStatusEntry) -> Void) {
        if context.isPreview {
            completion(PowerStatusEntry(date: .now, snapshot: .placeholder))
            return
        }

        Task {
            let snapshot = await PowerSampler().sample()
            completion(PowerStatusEntry(date: .now, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PowerStatusEntry>) -> Void) {
        Task {
            let snapshot = await PowerSampler().sample()
            let entry = PowerStatusEntry(date: .now, snapshot: snapshot)
            let refreshDate = Date.now.addingTimeInterval(5)
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        }
    }
}

struct PowerStatusWidgetEntryView: View {
    let entry: PowerStatusEntry

    var body: some View {
        if #available(macOS 14.0, *) {
            PowerStatusCard(snapshot: entry.snapshot, drawsShellBackground: false)
                .containerBackground(for: .widget) {
                    PowerStatusWidgetBackground()
                }
        } else {
            PowerStatusCard(snapshot: entry.snapshot)
                .padding(8)
        }
    }
}

struct PowerStatusWidget: Widget {
    let kind = "USBPowerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PowerStatusProvider()) { entry in
            PowerStatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("USB Power")
        .description("Battery health, battery draw, and best-available USB-C power contract data.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
