import SwiftUI

@main
struct BatteryWarnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(AppState.shared.batteryMonitor)
        }
    }
}

// Shared state that persists across the app
class AppState {
    static let shared = AppState()
    let batteryMonitor = BatteryMonitor()

    private init() {}
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var overlayWindowController: OverlayWindowController?
    var settingsWindow: NSWindow?

    var batteryMonitor: BatteryMonitor {
        AppState.shared.batteryMonitor
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: "Battery Warning")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // Subscribe to battery state changes
        batteryMonitor.onLowBattery = { [weak self] isCritical in
            self?.showOverlay(isCritical: isCritical)
        }

        batteryMonitor.onPowerRestored = { [weak self] in
            self?.hideOverlay()
        }

        batteryMonitor.startMonitoring()
        updateMenuBarIcon()

        // Subscribe to battery level updates for menu bar icon
        batteryMonitor.onBatteryUpdate = { [weak self] in
            self?.updateMenuBarIcon()
        }

        // Listen for test overlay notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTestOverlay),
            name: .showTestOverlay,
            object: nil
        )
    }

    @objc func handleTestOverlay() {
        // Test with non-critical mode
        showOverlay(isCritical: false)
        // Auto-hide after 5 seconds for testing
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.hideOverlay()
        }
    }

    func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }

        let level = batteryMonitor.batteryLevel
        let isPluggedIn = batteryMonitor.isPluggedIn

        let iconName: String
        if isPluggedIn {
            iconName = "battery.100.bolt"
        } else if level > 75 {
            iconName = "battery.100"
        } else if level > 50 {
            iconName = "battery.75"
        } else if level > 25 {
            iconName = "battery.50"
        } else if level > 10 {
            iconName = "battery.25"
        } else {
            iconName = "battery.0"
        }

        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Battery: \(level)%")
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(AppState.shared.batteryMonitor)

            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "BatteryWarn Settings"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 400, height: 620))
            window.center()

            self.settingsWindow = window
        }

        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showOverlay(isCritical: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.overlayWindowController == nil else { return }

            let controller = OverlayWindowController(
                batteryMonitor: self.batteryMonitor,
                isCritical: isCritical
            )

            // Handle dismiss from overlay
            controller.onDismiss = { [weak self] in
                self?.dismissOverlay()
            }

            self.overlayWindowController = controller
            controller.showOverlay()
        }
    }

    func hideOverlay() {
        DispatchQueue.main.async { [weak self] in
            self?.overlayWindowController?.hideOverlay()
            self?.overlayWindowController = nil
        }
    }

    func dismissOverlay() {
        DispatchQueue.main.async { [weak self] in
            self?.batteryMonitor.dismissOverlay()
            self?.overlayWindowController?.hideOverlay()
            self?.overlayWindowController = nil
        }
    }
}
