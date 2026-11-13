import XCTest
import SwiftUI
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
        try ScreenshotSupport.outputDirectory(fromEnvironment: "SCREENSHOT_DIR")
    }

    private func renderOverlay(_ model: OverlayModel, to name: String) throws {
        let directory = try outputDirectory()

        let window = try ScreenshotSupport.overlayWindow(model, size: overlaySize)
        let view = try XCTUnwrap(window.contentView)

        try ScreenshotSupport.writePNG(ScreenshotSupport.bitmap(of: view), to: directory.appendingPathComponent(name))
    }

    private func renderSettings(appearance: NSAppearance.Name, to name: String) throws {
        let directory = try outputDirectory()

        let view = SettingsView(
            loginItemAvailable: true,
            appVersion: try ScreenshotSupport.bundleVersion(),
            appIcon: try ScreenshotSupport.appIcon()
        )
        .environmentObject(try ScreenshotSupport.sampleMonitor(in: self))

        let window = SettingsWindow.make(rootView: view)
        window.appearance = NSAppearance(named: appearance)

        // Capture the frame view so the title bar is part of the picture
        let frameView = try XCTUnwrap(window.contentView?.superview)
        try ScreenshotSupport.writePNG(ScreenshotSupport.bitmap(of: frameView), to: directory.appendingPathComponent(name))
    }
}
