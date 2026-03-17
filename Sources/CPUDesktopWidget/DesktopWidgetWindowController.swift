import AppKit
import SwiftUI

final class DesktopWidgetWindowController: NSWindowController {
    private let metricsStore = MetricsStore()
    private let launchAtLoginController: LaunchAtLoginController

    init(launchAtLoginController: LaunchAtLoginController) {
        self.launchAtLoginController = launchAtLoginController

        let window = DesktopWidgetWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 260),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let contentView = CPUWidgetDashboard()
            .environmentObject(metricsStore)
            .environmentObject(launchAtLoginController)

        window.contentView = NSHostingView(rootView: contentView)
        window.centerOnMainScreen(margin: 32)

        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class DesktopWidgetWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing bufferingType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)

        title = "CPU Desktop Widget"
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .normal
        collectionBehavior = [.ignoresCycle]
        isMovable = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let screen else {
            return super.constrainFrameRect(frameRect, to: screen)
        }

        let inset: CGFloat = 28
        let visible = screen.visibleFrame.insetBy(dx: inset, dy: inset)
        var constrained = frameRect

        constrained.origin.x = min(max(constrained.origin.x, visible.minX), visible.maxX - constrained.width)
        constrained.origin.y = min(max(constrained.origin.y, visible.minY), visible.maxY - constrained.height)

        return constrained
    }

    func centerOnMainScreen(margin: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let origin = CGPoint(
            x: visibleFrame.maxX - frame.width - margin,
            y: visibleFrame.maxY - frame.height - margin
        )
        setFrameOrigin(origin)
    }
}
