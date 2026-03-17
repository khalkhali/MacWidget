import SwiftUI

struct CPUWidgetDashboard: View {
    @EnvironmentObject private var metricsStore: MetricsStore
    @EnvironmentObject private var launchAtLoginController: LaunchAtLoginController

    var body: some View {
        let snapshot = metricsStore.snapshot

        GeometryReader { proxy in
            let layout = WidgetLayout(size: proxy.size)

            ZStack(alignment: .topLeading) {
                shell(layout: layout)

                VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                    header(layout: layout)

                    HStack(alignment: .center, spacing: layout.mainRowSpacing) {
                        summary(snapshot: snapshot, layout: layout)

                        CircularGauge(
                            progress: snapshot.cpuUsage,
                            lineWidth: layout.gaugeLineWidth,
                            trackColor: Color.white.opacity(0.10),
                            gradient: Gradient(colors: [Color.accentColor, Color.cyan]),
                            centerLabel: "CPU",
                            centerValue: snapshot.cpuUsage.percentString,
                            centerSubtitle: "Usage"
                        )
                        .frame(width: layout.gaugeSize, height: layout.gaugeSize)
                        .offset(x: layout.gaugeOffsetX, y: layout.gaugeOffsetY)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    chipRow(snapshot: snapshot, layout: layout)

                    metricRow(snapshot: snapshot, layout: layout)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, layout.horizontalContentPadding)
                .padding(.top, layout.topContentPadding)
                .padding(.bottom, layout.bottomContentPadding)
            }
            .padding(layout.shellPadding)
            .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
    }

    private func shell(layout: WidgetLayout) -> some View {
        RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.07),
                                Color.blue.opacity(0.06),
                                Color.black.opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                    .blur(radius: 2)
            )
    }

    private func header(layout: WidgetLayout) -> some View {
        HStack(alignment: .center) {
            Label("CPU", systemImage: "cpu")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))

            Spacer()

            Image(systemName: "arrow.clockwise")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.56))
        }
        .contentShape(Rectangle())
        .overlay(WindowDragRegion())
    }

    private func summary(snapshot: SystemSnapshot, layout: WidgetLayout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.cpuUsage.percentString)
                .font(.system(size: layout.primaryValueSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.96))

            Text(snapshot.chipName)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text("\(snapshot.busyLogicalCPUs) / \(snapshot.logicalCPUs) active threads")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.74))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: 190, alignment: .leading)
    }

    private func chipRow(snapshot: SystemSnapshot, layout: WidgetLayout) -> some View {
        HStack(spacing: layout.chipSpacing) {
            InfoChip(label: "Thermal", value: snapshot.thermalLabel, cornerRadius: layout.innerCornerRadius)
            InfoChip(label: "System Thr", value: compactThreadCount(snapshot.systemThreads), cornerRadius: layout.innerCornerRadius)
            InfoChip(label: "Task Thr", value: compactThreadCount(snapshot.taskThreads), cornerRadius: layout.innerCornerRadius)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricRow(snapshot: SystemSnapshot, layout: WidgetLayout) -> some View {
        HStack(alignment: .top, spacing: layout.metricSpacing) {
            MetricGroup(
                title: "User",
                detail: "\(snapshot.userUsage.percentString) • \(snapshot.logicalCPUs) logical",
                accent: .accentColor
            )

            MetricGroup(
                title: "System",
                detail: "\(snapshot.systemUsage.percentString) • \(snapshot.physicalCPUs) physical",
                accent: .orange
            )

            MetricGroup(
                title: "Threads",
                detail: "\(snapshot.busyLogicalCPUs)/\(snapshot.logicalCPUs) • 1s refresh",
                accent: .mint
            )
        }
    }

    private func compactThreadCount(_ value: Int) -> String {
        if value >= 1000 {
            let compact = Double(value) / 1000
            return compact.formatted(.number.precision(.fractionLength(1))) + "k"
        }

        return value.formatted()
    }
}

private struct WidgetLayout {
    let size: CGSize

    var cornerRadius: CGFloat {
        min(max(size.height * 0.12, 26), 34)
    }

    var innerCornerRadius: CGFloat {
        min(max(size.height * 0.045, 12), 16)
    }

    var shellPadding: CGFloat {
        min(max(size.height * 0.035, 10), 14)
    }

    var horizontalContentPadding: CGFloat {
        min(max(size.height * 0.04, 12), 14)
    }

    var topContentPadding: CGFloat {
        min(max(size.height * 0.04, 12), 14)
    }

    var bottomContentPadding: CGFloat {
        6
    }

    var sectionSpacing: CGFloat {
        min(max(size.height * 0.03, 8), 10)
    }

    var mainRowSpacing: CGFloat {
        6
    }

    var chipSpacing: CGFloat {
        4
    }

    var metricSpacing: CGFloat {
        8
    }

    var gaugeSize: CGFloat {
        min(max(size.height * 0.37, 96), 112)
    }

    var gaugeOffsetX: CGFloat {
        -26
    }

    var gaugeOffsetY: CGFloat {
        -18
    }

    var gaugeLineWidth: CGFloat {
        13
    }

    var primaryValueSize: CGFloat {
        min(max(size.height * 0.16, 40), 50)
    }
}

private struct CircularGauge: View {
    let progress: Double
    let lineWidth: CGFloat
    let trackColor: Color
    let gradient: Gradient
    let centerLabel: String
    let centerValue: String
    let centerSubtitle: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.02, min(progress, 1)))
                .stroke(
                    AngularGradient(gradient: gradient, center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text(centerLabel.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.56))

                Text(centerValue)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(centerSubtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.60))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
    }
}

private struct InfoChip: View {
    let label: String
    let value: String
    let cornerRadius: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.60))

            Text(value)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct MetricGroup: View {
    let title: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(accent)
                    .frame(width: 7, height: 7)

                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.90))
            }

            Text(detail)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .layoutPriority(1)
    }
}

private extension Double {
    var percentString: String {
        "\(Int((self * 100).rounded()))%"
    }
}

private struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> DragRegionView {
        DragRegionView()
    }

    func updateNSView(_ nsView: DragRegionView, context: Context) {}
}

private final class DragRegionView: NSView {
    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
