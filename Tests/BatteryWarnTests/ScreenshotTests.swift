import XCTest
import SwiftUI
import IOKit.ps
@testable import BatteryWarn

/// Renders the README screenshots from the real views with fixed sample data.
/// Skipped in normal test runs; use scripts/make-screenshots.sh to regenerate.
final class ScreenshotTests: XCTestCase {
    private let overlaySize = CGSize(width: 1440, height: 900)

    func testOverlayWarning() throws {
        let model = OverlayModel(batteryLevel: 9, isCritical: false, minutesRemaining: 17, threshold: 10)

        try renderOverlay(model, to: "overlay-warning.png")
    }

    func testOverlayCritical() throws {
        let model = OverlayModel(batteryLevel: 4, isCritical: true, minutesRemaining: 6, threshold: 10)

        try renderOverlay(model, to: "overlay-critical.png")
    }

    func testSettingsLight() throws {
        try renderSettings(appearance: .aqua, to: "settings-light.png")
    }

    func testSettingsDark() throws {
        try renderSettings(appearance: .darkAqua, to: "settings-dark.png")
    }

    // MARK: - Rendering

    private func outputDirectory() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
            throw XCTSkip("Set SCREENSHOT_DIR to render screenshots")
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func renderOverlay(_ model: OverlayModel, to name: String) throws {
        let directory = try outputDirectory()

        // The overlay is translucent; stand in for the desktop behind it
        let view = ZStack {
            Color(white: 0.16)
            OverlayView(model: model)
        }
        .frame(width: overlaySize.width, height: overlaySize.height)

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: overlaySize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: view)

        try capture(window.contentView!, to: directory.appendingPathComponent(name))
    }

    private func renderSettings(appearance: NSAppearance.Name, to name: String) throws {
        let directory = try outputDirectory()

        let suite = "ScreenshotTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let monitor = BatteryMonitor(defaults: defaults, readPowerSource: {
            BatteryReading(description: [
                kIOPSCurrentCapacityKey: 64,
                kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
                kIOPSIsChargingKey: false,
                kIOPSTimeToEmptyKey: 312
            ])
        })

        let view = SettingsView(loginItemAvailable: true, appVersion: try bundleVersion(), appIcon: try appIcon())
            .environmentObject(monitor)

        let window = SettingsWindow.make(rootView: view)
        window.appearance = NSAppearance(named: appearance)

        // Capture the frame view so the title bar is part of the picture
        let frameView = try XCTUnwrap(window.contentView?.superview)
        try capture(frameView, to: directory.appendingPathComponent(name))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../..")
    }

    /// The test process has no app bundle, so load the icon the app will ship with
    private func appIcon() throws -> NSImage {
        try XCTUnwrap(NSImage(contentsOf: repositoryRoot.appendingPathComponent("AppIcon.png")))
    }

    /// Likewise for the version shown in the footer
    private func bundleVersion() throws -> String {
        let plistURL = repositoryRoot.appendingPathComponent("BatteryWarn/Info.plist")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), format: nil)
        return try XCTUnwrap((plist as? [String: Any])?["CFBundleShortVersionString"] as? String)
    }

    private func capture(_ view: NSView, to url: URL) throws {
        _ = NSApplication.shared
        view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)

        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: url)
    }
}
