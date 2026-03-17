import AppKit
import ServiceManagement
import SwiftUI

@main
struct CPUDesktopWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: DesktopWidgetWindowController?
    private let launchAtLoginController = LaunchAtLoginController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        launchAtLoginController.ensureEnabled()

        windowController = DesktopWidgetWindowController(
            launchAtLoginController: launchAtLoginController
        )
        windowController?.showWindow(self)
    }
}

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var statusDescription = "Starting at login"
    @Published private(set) var isEnabled = false

    func ensureEnabled() {
        guard #available(macOS 13.0, *) else {
            statusDescription = "Login start unsupported"
            return
        }

        let service = SMAppService.mainApp

        do {
            switch service.status {
            case .enabled:
                isEnabled = true
                statusDescription = "Starts at login"
            case .requiresApproval:
                isEnabled = false
                statusDescription = "Approve in Login Items"
            case .notFound:
                isEnabled = false
                statusDescription = "Move app bundle to Applications"
            case .notRegistered:
                try service.register()
                isEnabled = true
                statusDescription = "Starts at login"
            @unknown default:
                isEnabled = false
                statusDescription = "Login item unavailable"
            }
        } catch {
            isEnabled = false
            statusDescription = "Login start unavailable"
        }
    }
}
