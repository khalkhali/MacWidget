import SwiftUI
import WidgetKit

struct PowerStatusCard: View {
    let snapshot: PowerSnapshot
    let drawsShellBackground: Bool
    let familyOverride: WidgetFamily?

    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    init(snapshot: PowerSnapshot, drawsShellBackground: Bool = true, familyOverride: WidgetFamily? = nil) {
        self.snapshot = snapshot
        self.drawsShellBackground = drawsShellBackground
        self.familyOverride = familyOverride
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = PowerStatusCardLayout(size: proxy.size, family: familyOverride ?? widgetFamily)
            let theme = PowerStatusCardTheme(widgetRenderingMode: widgetRenderingMode)

            ZStack(alignment: .topLeading) {
                if drawsShellBackground {
                    PowerStatusWidgetBackground()
                }

                VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                    header(layout: layout, theme: theme)

                    HStack(alignment: .top, spacing: layout.mainRowSpacing) {
                        summary(layout: layout, theme: theme)

                        PowerGauge(
                            progress: snapshot.batteryFraction,
                            lineWidth: layout.gaugeLineWidth,
                            trackColor: theme.gaugeTrackColor,
                            gradient: Gradient(colors: theme.gaugeProgressColors),
                            labelColor: theme.tertiaryTextColor,
                            valueColor: theme.primaryTextColor,
                            subtitleColor: theme.secondaryTextColor
                        )
                        .frame(width: layout.gaugeSize, height: layout.gaugeSize)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        Spacer(minLength: 0)
                    }

                    chipRow(layout: layout, theme: theme)

                    metricRow(layout: layout, theme: theme)

                    if layout.showsPortGrid {
                        portGrid(layout: layout, theme: theme)
                            .padding(.bottom, layout.innerFrameBottomInset)
                    } else {
                        footer(layout: layout, theme: theme)
                            .padding(.bottom, layout.footerBottomInset)
                    }
                }
                .padding(.horizontal, layout.horizontalContentPadding)
                .padding(.top, layout.topContentPadding)
                .padding(.bottom, layout.bottomContentPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func header(layout: PowerStatusCardLayout, theme: PowerStatusCardTheme) -> some View {
        HStack(alignment: .center) {
            Label("Power", systemImage: "powerplug")
                .font(.system(size: layout.headerSize, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.secondaryTextColor)

            Spacer()

            Text(snapshot.sourceLabel)
                .font(.system(size: layout.headerSize, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.tertiaryTextColor)
        }
    }

    private func summary(layout: PowerStatusCardLayout, theme: PowerStatusCardTheme) -> some View {
        VStack(alignment: .leading, spacing: layout.summarySpacing) {
            Text("\(snapshot.batteryPercent)%")
                .font(.system(size: layout.primaryValueSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryTextColor)

            Text(snapshot.timeRemainingLabel)
                .font(.system(size: layout.secondaryValueSize, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("\(snapshot.cycleCount) cycles • \(snapshot.healthLabel) health")
                .font(.system(size: layout.detailSize, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: layout.summaryWidth, alignment: .leading)
    }

    private func chipRow(layout: PowerStatusCardLayout, theme: PowerStatusCardTheme) -> some View {
        HStack(spacing: layout.chipSpacing) {
            PowerChip(label: "USB-C", value: "\(snapshot.usbConnectedPortCount)/\(max(snapshot.usbPorts.count, 1))", layout: layout, theme: theme)
            PowerChip(label: "Health", value: snapshot.healthLabel, layout: layout, theme: theme)
            PowerChip(label: "Cycles", value: "\(snapshot.cycleCount)", layout: layout, theme: theme)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricRow(layout: PowerStatusCardLayout, theme: PowerStatusCardTheme) -> some View {
        HStack(alignment: .top, spacing: layout.metricSpacing) {
            PowerMetricGroup(
                title: "Voltage",
                detail: valueLabel(snapshot.voltageVolts, format: "%.2fV", fallback: "N/A"),
                accent: theme.voltageAccent,
                layout: layout,
                theme: theme
            )

            PowerMetricGroup(
                title: "Current",
                detail: valueLabel(snapshot.amperageAmps.map(abs), format: "%.2fA", fallback: "N/A"),
                accent: theme.currentAccent,
                layout: layout,
                theme: theme
            )

            PowerMetricGroup(
                title: "Power",
                detail: valueLabel(snapshot.powerWatts, format: "%.1fW", fallback: "N/A"),
                accent: theme.powerAccent,
                layout: layout,
                theme: theme
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func footer(layout: PowerStatusCardLayout, theme: PowerStatusCardTheme) -> some View {
        Text(snapshot.primaryUSBContractLabel)
            .font(.system(size: layout.footerSize, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.tertiaryTextColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func portGrid(layout: PowerStatusCardLayout, theme: PowerStatusCardTheme) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: layout.portSpacing) {
            ForEach(snapshot.usbPorts) { port in
                VStack(alignment: .leading, spacing: layout.portContentSpacing) {
                    Text("Port \(port.index)")
                        .font(.system(size: layout.portTitleSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.primaryTextColor)

                    Text(port.statusLabel)
                        .font(.system(size: layout.portStatusSize, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.secondaryTextColor)
                        .lineLimit(1)

                    Text(port.electricalSummary)
                        .font(.system(size: layout.portDetailSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.tertiaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, layout.portPaddingHorizontal)
                .padding(.vertical, layout.portPaddingVertical)
                .background(
                    RoundedRectangle(cornerRadius: layout.innerCornerRadius, style: .continuous)
                        .fill(theme.portFillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: layout.innerCornerRadius, style: .continuous)
                        .strokeBorder(theme.portBorderColor, lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valueLabel(_ value: Double?, format: String, fallback: String) -> String {
        guard let value else { return fallback }
        return String(format: format, value)
    }
}

struct PowerStatusWidgetBackground: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    var body: some View {
        GeometryReader { proxy in
            let layout = PowerStatusCardLayout(size: proxy.size, family: .systemMedium)
            let theme = PowerStatusCardTheme(widgetRenderingMode: widgetRenderingMode)

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

private struct PowerStatusCardLayout {
    let size: CGSize
    let family: WidgetFamily

    var isLarge: Bool { family == .systemLarge }

    var cornerRadius: CGFloat { min(max(size.height * 0.14, 22), 32) }
    var innerCornerRadius: CGFloat { min(max(size.height * 0.06, 10), 16) }
    var shellPadding: CGFloat { 2 }
    var horizontalContentPadding: CGFloat { isLarge ? 14 : 10 }
    var topContentPadding: CGFloat { isLarge ? 10 : 8 }
    var bottomContentPadding: CGFloat { isLarge ? 24 : 14 }
    var sectionSpacing: CGFloat { isLarge ? 6 : 5 }
    var mainRowSpacing: CGFloat { isLarge ? 12 : 8 }
    var chipSpacing: CGFloat { 4 }
    var metricSpacing: CGFloat { isLarge ? 14 : 10 }
    var innerFrameBottomInset: CGFloat { isLarge ? 12 : 0 }
    var footerBottomInset: CGFloat { isLarge ? 4 : 2 }
    var summaryWidth: CGFloat { isLarge ? min(size.width * 0.34, 190) : min(size.width * 0.34, 128) }
    var gaugeSize: CGFloat { isLarge ? min(max(size.height * 0.30, 90), 114) : min(max(size.height * 0.42, 74), 88) }
    var gaugeLineWidth: CGFloat { isLarge ? 11 : 10 }
    var primaryValueSize: CGFloat { isLarge ? 36 : min(max(size.height * 0.18, 28), 36) }
    var secondaryValueSize: CGFloat { isLarge ? 14 : 11 }
    var detailSize: CGFloat { isLarge ? 12 : 10 }
    var headerSize: CGFloat { isLarge ? 12 : 10 }
    var summarySpacing: CGFloat { isLarge ? 4 : 3 }
    var chipFontSize: CGFloat { isLarge ? 9 : 7 }
    var metricTitleSize: CGFloat { isLarge ? 11 : 9 }
    var metricDetailSize: CGFloat { isLarge ? 11 : 9 }
    var footerSize: CGFloat { isLarge ? 12 : 9 }
    var chipHorizontalPadding: CGFloat { isLarge ? 8 : 6 }
    var chipVerticalPadding: CGFloat { isLarge ? 4 : 3 }
    var chipItemSpacing: CGFloat { isLarge ? 7 : 6 }
    var metricGroupSpacing: CGFloat { isLarge ? 4 : 3 }
    var metricDotSize: CGFloat { isLarge ? 7 : 6 }
    var metricDotCornerRadius: CGFloat { isLarge ? 3 : 2.5 }
    var showsPortGrid: Bool { isLarge }
    var portSpacing: CGFloat { 6 }
    var portTitleSize: CGFloat { 10 }
    var portStatusSize: CGFloat { 9 }
    var portDetailSize: CGFloat { 9 }
    var portPaddingHorizontal: CGFloat { 9 }
    var portPaddingVertical: CGFloat { 6 }
    var portContentSpacing: CGFloat { 2 }
}

private struct PowerStatusCardTheme {
    let widgetRenderingMode: WidgetRenderingMode

    var usesReducedWidgetRendering: Bool {
        widgetRenderingMode != .fullColor
    }

    var widgetContainerFillColor: Color {
        usesReducedWidgetRendering ? Color.black.opacity(0.99) : Color.black.opacity(0.36)
    }

    var widgetContainerOverlayColors: [Color] {
        if usesReducedWidgetRendering {
            return [
                Color.white.opacity(0.015),
                Color.black.opacity(0.06),
                Color.black.opacity(0.30)
            ]
        }

        return [
            Color.white.opacity(0.07),
            Color.green.opacity(0.06),
            Color.black.opacity(0.18)
        ]
    }

    var widgetContainerBorderColor: Color {
        Color.white.opacity(usesReducedWidgetRendering ? 0.14 : 0.20)
    }

    var primaryTextColor: Color { Color.white.opacity(usesReducedWidgetRendering ? 0.98 : 0.96) }
    var secondaryTextColor: Color { Color.white.opacity(usesReducedWidgetRendering ? 0.82 : 0.76) }
    var tertiaryTextColor: Color { Color.white.opacity(usesReducedWidgetRendering ? 0.68 : 0.60) }
    var chipFillColor: Color { Color.white.opacity(usesReducedWidgetRendering ? 0.06 : 0.08) }
    var chipBorderColor: Color { Color.white.opacity(usesReducedWidgetRendering ? 0.05 : 0.04) }
    var portFillColor: Color { Color.white.opacity(usesReducedWidgetRendering ? 0.05 : 0.06) }
    var portBorderColor: Color { Color.white.opacity(usesReducedWidgetRendering ? 0.04 : 0.05) }
    var gaugeTrackColor: Color { Color.white.opacity(usesReducedWidgetRendering ? 0.12 : 0.10) }
    var gaugeProgressColors: [Color] {
        usesReducedWidgetRendering ? [Color.white.opacity(0.98), Color.white.opacity(0.80)] : [Color.green, Color.cyan]
    }
    var voltageAccent: Color { usesReducedWidgetRendering ? Color.white.opacity(0.95) : .green }
    var currentAccent: Color { usesReducedWidgetRendering ? Color.white.opacity(0.84) : .yellow }
    var powerAccent: Color { usesReducedWidgetRendering ? Color.white.opacity(0.74) : .mint }
}

private struct PowerGauge: View {
    let progress: Double
    let lineWidth: CGFloat
    let trackColor: Color
    let gradient: Gradient
    let labelColor: Color
    let valueColor: Color
    let subtitleColor: Color

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
                .widgetAccentable()

            VStack(spacing: 4) {
                Text("BATT")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(labelColor)

                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Battery")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(subtitleColor)
            }
        }
    }
}

private struct PowerChip: View {
    let label: String
    let value: String
    let layout: PowerStatusCardLayout
    let theme: PowerStatusCardTheme

    var body: some View {
        HStack(spacing: layout.chipItemSpacing) {
            Text(label)
                .font(.system(size: layout.chipFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(theme.tertiaryTextColor)

            Text(value)
                .font(.system(size: layout.chipFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, layout.chipHorizontalPadding)
        .padding(.vertical, layout.chipVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: layout.innerCornerRadius, style: .continuous)
                .fill(theme.chipFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: layout.innerCornerRadius, style: .continuous)
                .strokeBorder(theme.chipBorderColor, lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct PowerMetricGroup: View {
    let title: String
    let detail: String
    let accent: Color
    let layout: PowerStatusCardLayout
    let theme: PowerStatusCardTheme

    var body: some View {
        VStack(alignment: .leading, spacing: layout.metricGroupSpacing) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: layout.metricDotCornerRadius, style: .continuous)
                    .fill(accent)
                    .frame(width: layout.metricDotSize, height: layout.metricDotSize)
                    .widgetAccentable()

                Text(title)
                    .font(.system(size: layout.metricTitleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.primaryTextColor)
            }

            Text(detail)
                .font(.system(size: layout.metricDetailSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .layoutPriority(1)
    }
}
