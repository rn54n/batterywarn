import SwiftUI
import AppKit

enum SettingsWindow {
    /// Settings window whose content runs up under a transparent title bar
    static func make<Content: View>(rootView: Content) -> NSWindow {
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "BatteryWarn Settings"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.setContentSize(hostingController.view.fittingSize)

        return window
    }
}
