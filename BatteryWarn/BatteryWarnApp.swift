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
    var statusMenuItem: NSMenuItem!
    var overlayWindowController: OverlayWindowController?
    var settingsWindow: NSWindow?

    var batteryMonitor: BatteryMonitor {
        AppState.shared.batteryMonitor
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppAppearance.saved.apply()

        // Setup menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: "Battery Warning")
        }

        let menu = NSMenu()

        // Read-only battery summary (no action = shown disabled)
        statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Test Warning", action: #selector(handleTestOverlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit BatteryWarn", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // Subscribe to battery state changes
        batteryMonitor.onWarningChange = { [weak self] level in
            self?.warningChanged(to: level)
        }

        // Subscribe to battery level updates for menu bar and open overlay
        batteryMonitor.onBatteryUpdate = { [weak self] in
            self?.updateMenuBar()
            self?.updateOverlay()
        }

        batteryMonitor.startMonitoring()

        // Listen for test overlay notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTestOverlay),
            name: .showTestOverlay,
            object: nil
        )
    }

    func updateMenuBar() {
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

        statusMenuItem.title = BatteryFormat.menuStatus(
            level: level,
            isPluggedIn: isPluggedIn,
            isCharging: batteryMonitor.isCharging,
            minutesRemaining: batteryMonitor.minutesRemaining
        )
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(AppState.shared.batteryMonitor)

            let window = SettingsWindow.make(rootView: settingsView)
            window.center()

            self.settingsWindow = window
        }

        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Warning Overlay

    func warningChanged(to level: WarningLevel) {
        guard level != .none else {
            // A test preview is not the monitor's to close
            if overlayWindowController?.model.isTest == false {
                hideOverlay()
            }
            return
        }

        // Already warning: let the open overlay escalate in place
        if let model = overlayWindowController?.model, !model.isTest {
            model.isCritical = level == .critical
            return
        }

        // A real warning replaces a running test preview
        hideOverlay()

        let model = OverlayModel(
            batteryLevel: batteryMonitor.batteryLevel,
            isCritical: level == .critical,
            minutesRemaining: batteryMonitor.minutesRemaining,
            threshold: batteryMonitor.threshold,
            allowsDismiss: batteryMonitor.allowsDismiss
        )
        model.onDismiss = { [weak self] in
            self?.batteryMonitor.dismissOverlay()
        }
        showOverlay(with: model)
    }

    /// Keep an open warning in step with the battery
    func updateOverlay() {
        guard let model = overlayWindowController?.model, !model.isTest else { return }

        model.batteryLevel = batteryMonitor.batteryLevel
        model.minutesRemaining = batteryMonitor.minutesRemaining
    }

    @objc func handleTestOverlay() {
        // Never cover a real warning with a preview
        guard overlayWindowController == nil else { return }

        // Preview what the warning looks like at the configured threshold
        let model = OverlayModel(
            batteryLevel: batteryMonitor.threshold,
            isCritical: false,
            threshold: batteryMonitor.threshold,
            allowsDismiss: batteryMonitor.allowsDismiss,
            isTest: true
        )
        model.onDismiss = { [weak self] in
            self?.hideOverlay()
        }
        showOverlay(with: model)

        // Auto-hide after 5 seconds, unless something else took over the screen
        let preview = overlayWindowController
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self, weak preview] in
            guard let self = self, let preview = preview, self.overlayWindowController === preview else { return }
            self.hideOverlay()
        }
    }

    func showOverlay(with model: OverlayModel) {
        let controller = OverlayWindowController(model: model)
        overlayWindowController = controller
        controller.showOverlay()
    }

    func hideOverlay() {
        overlayWindowController?.hideOverlay()
        overlayWindowController = nil
    }
}
