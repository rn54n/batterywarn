import SwiftUI
import AppKit

class OverlayWindowController {
    private var windows: [NSWindow] = []
    private var batteryMonitor: BatteryMonitor
    private var isCritical: Bool
    var onDismiss: (() -> Void)?

    init(batteryMonitor: BatteryMonitor, isCritical: Bool) {
        self.batteryMonitor = batteryMonitor
        self.isCritical = isCritical
    }

    func showOverlay() {
        for screen in NSScreen.screens {
            let window = createOverlayWindow(for: screen)
            windows.append(window)
            window.orderFrontRegardless()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func hideOverlay() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }

    private func createOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        let overlayView = OverlayView(
            batteryMonitor: batteryMonitor,
            isCritical: isCritical,
            onDismiss: { [weak self] in
                self?.onDismiss?()
            }
        )
        let hostingView = NSHostingView(rootView: overlayView)

        window.contentView = hostingView

        // Critical = higher window level, blocks more
        // Non-critical = lower level, allows some system interaction
        window.level = isCritical ? .screenSaver : .floating

        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false

        // Allow system sleep
        window.preventsApplicationTerminationWhenModal = false

        return window
    }
}
