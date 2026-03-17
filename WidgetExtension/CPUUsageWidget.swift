import SwiftUI
import WidgetKit

struct CPUUsageEntry: TimelineEntry {
    let date: Date
    let snapshot: SystemSnapshot
}

struct CPUUsageProvider: TimelineProvider {
    func placeholder(in context: Context) -> CPUUsageEntry {
        CPUUsageEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CPUUsageEntry) -> Void) {
        if context.isPreview {
            completion(CPUUsageEntry(date: .now, snapshot: .placeholder))
            return
        }

        Task {
            let snapshot = await MetricSampler().sample()
            completion(CPUUsageEntry(date: .now, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CPUUsageEntry>) -> Void) {
        Task {
            let snapshot = await MetricSampler().sample()
            let entry = CPUUsageEntry(date: .now, snapshot: snapshot)
            let refreshDate = Date.now.addingTimeInterval(30)
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        }
    }
}

struct CPUUsageWidgetEntryView: View {
    let entry: CPUUsageEntry

    var body: some View {
        if #available(macOS 14.0, *) {
            CPUUsageCard(snapshot: entry.snapshot, style: .widget, drawsShellBackground: false)
                .containerBackground(for: .widget) {
                    CPUUsageWidgetBackground()
                }
        } else {
            CPUUsageCard(snapshot: entry.snapshot, style: .widget)
                .padding(8)
        }
    }
}

struct CPUUsageWidget: Widget {
    let kind = "CPUUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CPUUsageProvider()) { entry in
            CPUUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("CPU Usage")
        .description("CPU usage, threads, and thermal state.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
