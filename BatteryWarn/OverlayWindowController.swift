import SwiftUI
import AppKit
import Combine

class OverlayWindowController {
    let model: OverlayModel

    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    private var escTimer: Timer?
    private var criticalObserver: AnyCancellable?
    private var previousApp: NSRunningApplication?

    private let escTimerInterval: TimeInterval = 0.05

    init(model: OverlayModel) {
        self.model = model
    }

    func showOverlay() {
        // Remember what the user was working in, to hand the keyboard back later
        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp = frontmost == .current ? nil : frontmost

        for screen in NSScreen.screens {
            let window = createOverlayWindow(for: screen)
            window.alphaValue = 0
            windows.append(window)
            window.orderFrontRegardless()
        }

        windows.first?.makeKey()
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            for window in windows {
                window.animator().alphaValue = 1
            }
        }

        // Follow the model when an open warning turns critical
        criticalObserver = model.$isCritical
            .removeDuplicates()
            .sink { [weak self] isCritical in
                guard let self = self else { return }
                let level = Self.windowLevel(isBlocking: isCritical || !self.model.allowsDismiss)
                self.windows.forEach { $0.level = level }
            }

        setupKeyMonitor()
    }

    func hideOverlay() {
        removeKeyMonitor()
        criticalObserver = nil

        // Keep the windows alive until the fade has finished
        let closing = windows
        windows.removeAll()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            for window in closing {
                window.animator().alphaValue = 0
            }
        }, completionHandler: {
            for window in closing {
                window.orderOut(nil)
            }
        })

        if let app = previousApp, !app.isTerminated {
            NSApp.yieldActivation(to: app)
            app.activate()
        }
        previousApp = nil
    }

    private func createOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.contentView = NSHostingView(rootView: OverlayView(model: model))
        window.level = Self.windowLevel(isBlocking: model.isCritical || !model.allowsDismiss)

        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false

        // Allow system sleep
        window.preventsApplicationTerminationWhenModal = false

        return window
    }

    // Critical or not dismissable = higher window level, blocks more
    // Otherwise = lower level, allows some system interaction
    private static func windowLevel(isBlocking: Bool) -> NSWindow.Level {
        isBlocking ? .screenSaver : .floating
    }

    // MARK: - ESC Key Handling

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self, event.keyCode == 53 else { return event } // ESC key

            if event.type == .keyDown && !event.isARepeat {
                self.model.escPressed()
                self.startEscTimer()
            } else if event.type == .keyUp {
                self.model.escReleased()
                self.stopEscTimer()
            }
            return nil // Consume the event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        stopEscTimer()
    }

    /// Drives the hold progress while ESC is down in critical mode
    private func startEscTimer() {
        guard model.isHoldingEsc, escTimer == nil else { return }

        let timer = Timer(timeInterval: escTimerInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.model.advanceHold(by: self.escTimerInterval)
            if !self.model.isHoldingEsc {
                self.stopEscTimer()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        escTimer = timer
    }

    private func stopEscTimer() {
        escTimer?.invalidate()
        escTimer = nil
    }

    deinit {
        removeKeyMonitor()
    }
}

/// Borderless windows refuse key status by default; the overlay should own the keyboard while it is up
private class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }

    // Swallow typing that was meant for the app underneath instead of beeping
    override func keyDown(with event: NSEvent) {}
}
