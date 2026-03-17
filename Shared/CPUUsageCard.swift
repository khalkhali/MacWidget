import SwiftUI
import WidgetKit

enum CPUUsageCardStyle {
    case appPreview
    case widget
}

struct CPUUsageCard: View {
    let snapshot: SystemSnapshot
    let style: CPUUsageCardStyle
    let drawsShellBackground: Bool

    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    init(snapshot: SystemSnapshot, style: CPUUsageCardStyle, drawsShellBackground: Bool = true) {
        self.snapshot = snapshot
        self.style = style
        self.drawsShellBackground = drawsShellBackground
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = CPUUsageCardLayout(size: proxy.size, style: style)
            let theme = CPUUsageCardTheme(style: style, widgetRenderingMode: widgetRenderingMode)

            ZStack(alignment: .topLeading) {
                if drawsShellBackground {
                    shellBackground(layout: layout, theme: theme)
                }

                VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                    header(layout: layout, theme: theme)

                    HStack(alignment: .center, spacing: layout.mainRowSpacing) {
                        summary(layout: layout, theme: theme)

                        CircularGauge(
                            progress: snapshot.cpuUsage,
                            lineWidth: layout.gaugeLineWidth,
                            trackColor: theme.gaugeTrackColor,
                            gradient: Gradient(colors: theme.gaugeProgressColors),
                            centerLabel: "CPU",
                            centerValue: snapshot.cpuUsage.percentString,
                            centerSubtitle: "Usage",
                            labelSize: layout.gaugeLabelSize,
                            valueSize: layout.gaugeValueSize,
                            subtitleSize: layout.gaugeSubtitleSize,
                            labelColor: theme.tertiaryTextColor,
                            valueColor: theme.primaryTextColor,
                            subtitleColor: theme.secondaryTextColor,
                            accentableProgress: theme.usesReducedWidgetRendering
                        )
                        .frame(width: layout.gaugeSize, height: layout.gaugeSize)
                        .offset(x: layout.gaugeOffsetX, y: layout.gaugeOffsetY)

                        Spacer(minLength: 0)
                    }

                    chipRow(layout: layout, theme: theme)

                    metricRow(layout: layout, theme: theme)
                }
                .padding(.horizontal, layout.horizontalContentPadding)
                .padding(.top, layout.topContentPadding)
                .padding(.bottom, layout.bottomContentPadding)
            }
            .padding(layout.shellPadding)
            .shadow(color: .black.opacity(style == .appPreview ? 0.16 : 0), radius: 16, y: 8)
        }
    }

    @ViewBuilder
    private func shellBackground(layout: CPUUsageCardLayout, theme: CPUUsageCardTheme) -> some View {
        let shape = RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)

        if theme.usesReducedWidgetRendering {
            shape
                .fill(theme.shellFillColor)
                .overlay(
                    shape.fill(
                        LinearGradient(
                            colors: theme.shellOverlayColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay(
                    shape.strokeBorder(theme.borderColor, lineWidth: 1)
                )
        } else {
            shape
                .fill(.regularMaterial)
                .overlay(
                    shape.fill(
                        LinearGradient(
                            colors: theme.shellOverlayColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay(
                    shape.strokeBorder(theme.borderColor, lineWidth: 1)
                )
        }
    }

    private func header(layout: CPUUsageCardLayout, theme: CPUUsageCardTheme) -> some View {
        HStack(alignment: .center) {
            Label("CPU", systemImage: "cpu")
                .font(.system(size: layout.headerSize, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.secondaryTextColor)

            Spacer()

            Image(systemName: "arrow.clockwise")
                .font(.system(size: layout.refreshSize, weight: .medium))
                .foregroundStyle(theme.tertiaryTextColor)
        }
    }

    private func summary(layout: CPUUsageCardLayout, theme: CPUUsageCardTheme) -> some View {
        VStack(alignment: .leading, spacing: layout.summarySpacing) {
            Text(snapshot.cpuUsage.percentString)
                .font(.system(size: layout.primaryValueSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryTextColor)

            Text(snapshot.chipName)
                .font(.system(size: layout.secondaryValueSize, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text("\(snapshot.busyLogicalCPUs) / \(snapshot.logicalCPUs) active threads")
                .font(.system(size: layout.detailSize, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: layout.summaryWidth, alignment: .leading)
    }

    private func chipRow(layout: CPUUsageCardLayout, theme: CPUUsageCardTheme) -> some View {
        HStack(spacing: layout.chipSpacing) {
            InfoChip(
                label: "Thermal",
                value: snapshot.thermalLabel,
                cornerRadius: layout.innerCornerRadius,
                fontSize: layout.chipFontSize,
                horizontalPadding: layout.chipHorizontalPadding,
                verticalPadding: layout.chipVerticalPadding,
                itemSpacing: layout.chipItemSpacing,
                labelColor: theme.tertiaryTextColor,
                valueColor: theme.primaryTextColor,
                fillColor: theme.chipFillColor,
                borderColor: theme.chipBorderColor
            )
            InfoChip(
                label: "System Thr",
                value: compactThreadCount(snapshot.systemThreads),
                cornerRadius: layout.innerCornerRadius,
                fontSize: layout.chipFontSize,
                horizontalPadding: layout.chipHorizontalPadding,
                verticalPadding: layout.chipVerticalPadding,
                itemSpacing: layout.chipItemSpacing,
                labelColor: theme.tertiaryTextColor,
                valueColor: theme.primaryTextColor,
                fillColor: theme.chipFillColor,
                borderColor: theme.chipBorderColor
            )
            InfoChip(
                label: "Task Thr",
                value: compactThreadCount(snapshot.taskThreads),
                cornerRadius: layout.innerCornerRadius,
                fontSize: layout.chipFontSize,
                horizontalPadding: layout.chipHorizontalPadding,
                verticalPadding: layout.chipVerticalPadding,
                itemSpacing: layout.chipItemSpacing,
                labelColor: theme.tertiaryTextColor,
                valueColor: theme.primaryTextColor,
                fillColor: theme.chipFillColor,
                borderColor: theme.chipBorderColor
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricRow(layout: CPUUsageCardLayout, theme: CPUUsageCardTheme) -> some View {
        HStack(alignment: .top, spacing: layout.metricSpacing) {
            MetricGroup(
                title: "User",
                detail: "\(snapshot.userUsage.percentString) • \(snapshot.logicalCPUs) logical",
                accent: theme.userMetricAccent,
                titleSize: layout.metricTitleSize,
                detailSize: layout.metricDetailSize,
                verticalSpacing: layout.metricGroupSpacing,
                dotSize: layout.metricDotSize,
                dotCornerRadius: layout.metricDotCornerRadius,
                titleColor: theme.primaryTextColor,
                detailColor: theme.secondaryTextColor,
                accentableAccent: theme.usesReducedWidgetRendering
            )

            MetricGroup(
                title: "System",
                detail: "\(snapshot.systemUsage.percentString) • \(snapshot.physicalCPUs) physical",
                accent: theme.systemMetricAccent,
                titleSize: layout.metricTitleSize,
                detailSize: layout.metricDetailSize,
                verticalSpacing: layout.metricGroupSpacing,
                dotSize: layout.metricDotSize,
                dotCornerRadius: layout.metricDotCornerRadius,
                titleColor: theme.primaryTextColor,
                detailColor: theme.secondaryTextColor,
                accentableAccent: theme.usesReducedWidgetRendering
            )

            MetricGroup(
                title: "Threads",
                detail: "\(snapshot.busyLogicalCPUs)/\(snapshot.logicalCPUs) • 1m refresh",
                accent: theme.threadMetricAccent,
                titleSize: layout.metricTitleSize,
                detailSize: layout.metricDetailSize,
                verticalSpacing: layout.metricGroupSpacing,
                dotSize: layout.metricDotSize,
                dotCornerRadius: layout.metricDotCornerRadius,
                titleColor: theme.primaryTextColor,
                detailColor: theme.secondaryTextColor,
                accentableAccent: theme.usesReducedWidgetRendering
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

struct CPUUsageWidgetBackground: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    var body: some View {
        GeometryReader { proxy in
            let layout = CPUUsageCardLayout(size: proxy.size, style: .widget)
            let theme = CPUUsageCardTheme(style: .widget, widgetRenderingMode: widgetRenderingMode)

            RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                .fill(theme.widgetContainerFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: theme.widgetContainerOverlayColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                        .strokeBorder(theme.widgetContainerBorderColor, lineWidth: 1)
                )
                .padding(layout.shellPadding)
        }
    }
}

private struct CPUUsageCardTheme {
    let style: CPUUsageCardStyle
    let widgetRenderingMode: WidgetRenderingMode

    var usesReducedWidgetRendering: Bool {
        style == .widget && widgetRenderingMode != .fullColor
    }

    var shellFillColor: Color {
        Color.black.opacity(usesReducedWidgetRendering ? 0.96 : 0.34)
    }

    var shellOverlayColors: [Color] {
        if usesReducedWidgetRendering {
            return [
                Color.white.opacity(0.025),
                Color.black.opacity(0.08),
                Color.black.opacity(0.36)
            ]
        }

        return [
            Color.white.opacity(0.07),
            Color.blue.opacity(0.06),
            Color.black.opacity(0.16)
        ]
    }

    var borderColor: Color {
        Color.white.opacity(usesReducedWidgetRendering ? 0.16 : 0.20)
    }

    var widgetContainerFillColor: Color {
        if usesReducedWidgetRendering {
            return Color.black.opacity(0.99)
        }

        return Color.black.opacity(0.36)
    }

    var widgetContainerOverlayColors: [Color] {
        if usesReducedWidgetRendering {
            return [
                Color.white.opacity(0.015),
                Color.black.opacity(0.06),
                Color.black.opacity(0.30)
            ]
        }

        return shellOverlayColors
    }

    var widgetContainerBorderColor: Color {
        Color.white.opacity(usesReducedWidgetRendering ? 0.14 : 0.20)
    }

    var primaryTextColor: Color {
        Color.white.opacity(usesReducedWidgetRendering ? 0.98 : 0.96)
    }

    var secondaryTextColor: Color {
        Color.white.opacity(usesReducedWidgetRendering ? 0.82 : 0.76)
    }

    var tertiaryTextColor: Color {
        Color.white.opacity(usesReducedWidgetRendering ? 0.68 : 0.60)
    }

    var chipFillColor: Color {
        Color.white.opacity(usesReducedWidgetRendering ? 0.06 : 0.08)
    }

    var chipBorderColor: Color {
        Color.white.opacity(usesReducedWidgetRendering ? 0.05 : 0.04)
    }

    var gaugeTrackColor: Color {
        Color.white.opacity(usesReducedWidgetRendering ? 0.12 : 0.10)
    }

    var gaugeProgressColors: [Color] {
        if usesReducedWidgetRendering {
            return [
                Color.white.opacity(0.98),
                Color.white.opacity(0.80)
            ]
        }

        return [Color.accentColor, Color.cyan]
    }

    var userMetricAccent: Color {
        usesReducedWidgetRendering ? Color.white.opacity(0.95) : .accentColor
    }

    var systemMetricAccent: Color {
        usesReducedWidgetRendering ? Color.white.opacity(0.84) : .orange
    }

    var threadMetricAccent: Color {
        usesReducedWidgetRendering ? Color.white.opacity(0.74) : .mint
    }
}

private struct CPUUsageCardLayout {
    let size: CGSize
    let style: CPUUsageCardStyle

    var isWidget: Bool { style == .widget }

    var cornerRadius: CGFloat {
        min(max(size.height * 0.14, 22), 32)
    }

    var innerCornerRadius: CGFloat {
        min(max(size.height * 0.06, 10), 16)
    }

    var shellPadding: CGFloat {
        isWidget ? 2 : 8
    }

    var horizontalContentPadding: CGFloat {
        isWidget ? 10 : 12
    }

    var topContentPadding: CGFloat {
        isWidget ? 8 : 12
    }

    var bottomContentPadding: CGFloat {
        isWidget ? 6 : 6
    }

    var sectionSpacing: CGFloat {
        isWidget ? 5 : 8
    }

    var mainRowSpacing: CGFloat {
        isWidget ? 8 : 6
    }

    var chipSpacing: CGFloat {
        isWidget ? 4 : 4
    }

    var metricSpacing: CGFloat {
        isWidget ? 10 : 8
    }

    var summaryWidth: CGFloat {
        isWidget ? min(size.width * 0.34, 126) : 190
    }

    var gaugeSize: CGFloat {
        isWidget ? min(max(size.height * 0.42, 74), 88) : min(max(size.height * 0.37, 96), 112)
    }

    var gaugeLineWidth: CGFloat {
        isWidget ? 10 : 13
    }

    var gaugeOffsetX: CGFloat {
        isWidget ? -40 : 0
    }

    var gaugeOffsetY: CGFloat {
        isWidget ? -8 : 0
    }

    var primaryValueSize: CGFloat {
        isWidget ? min(max(size.height * 0.18, 28), 36) : min(max(size.height * 0.16, 40), 50)
    }

    var secondaryValueSize: CGFloat {
        isWidget ? 11 : 16
    }

    var detailSize: CGFloat {
        isWidget ? 10 : 15
    }

    var headerSize: CGFloat {
        isWidget ? 10 : 13
    }

    var refreshSize: CGFloat {
        isWidget ? 12 : 15
    }

    var summarySpacing: CGFloat {
        isWidget ? 3 : 8
    }

    var chipFontSize: CGFloat {
        isWidget ? 7 : 9
    }

    var metricTitleSize: CGFloat {
        isWidget ? 9 : 12
    }

    var metricDetailSize: CGFloat {
        isWidget ? 9 : 12
    }

    var gaugeLabelSize: CGFloat {
        isWidget ? 8 : 10
    }

    var gaugeValueSize: CGFloat {
        isWidget ? 16 : 23
    }

    var gaugeSubtitleSize: CGFloat {
        isWidget ? 8 : 10
    }

    var chipHorizontalPadding: CGFloat {
        isWidget ? 6 : 8
    }

    var chipVerticalPadding: CGFloat {
        isWidget ? 3 : 5
    }

    var chipItemSpacing: CGFloat {
        isWidget ? 6 : 8
    }

    var metricGroupSpacing: CGFloat {
        isWidget ? 3 : 6
    }

    var metricDotSize: CGFloat {
        isWidget ? 6 : 7
    }

    var metricDotCornerRadius: CGFloat {
        isWidget ? 2.5 : 3
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
    let labelSize: CGFloat
    let valueSize: CGFloat
    let subtitleSize: CGFloat
    let labelColor: Color
    let valueColor: Color
    let subtitleColor: Color
    let accentableProgress: Bool

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
                .widgetAccentableIf(accentableProgress)

            VStack(spacing: 4) {
                Text(centerLabel.uppercased())
                    .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(labelColor)

                Text(centerValue)
                    .font(.system(size: valueSize, weight: .bold, design: .rounded))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(centerSubtitle)
                    .font(.system(size: subtitleSize, weight: .medium, design: .rounded))
                    .foregroundStyle(subtitleColor)
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
    let fontSize: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let itemSpacing: CGFloat
    let labelColor: Color
    let valueColor: Color
    let fillColor: Color
    let borderColor: Color

    var body: some View {
        HStack(spacing: itemSpacing) {
            Text(label)
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .foregroundStyle(labelColor)

            Text(value)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct MetricGroup: View {
    let title: String
    let detail: String
    let accent: Color
    let titleSize: CGFloat
    let detailSize: CGFloat
    let verticalSpacing: CGFloat
    let dotSize: CGFloat
    let dotCornerRadius: CGFloat
    let titleColor: Color
    let detailColor: Color
    let accentableAccent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: verticalSpacing) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: dotCornerRadius, style: .continuous)
                    .fill(accent)
                    .frame(width: dotSize, height: dotSize)
                    .widgetAccentableIf(accentableAccent)

                Text(title)
                    .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(titleColor)
            }

            Text(detail)
                .font(.system(size: detailSize, weight: .bold, design: .rounded))
                .foregroundStyle(detailColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .layoutPriority(1)
    }
}

private extension View {
    @ViewBuilder
    func widgetAccentableIf(_ isEnabled: Bool) -> some View {
        if isEnabled {
            self.widgetAccentable()
        } else {
            self
        }
    }
}
