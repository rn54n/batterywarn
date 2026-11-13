import XCTest
import SwiftUI
import IOKit.ps
@testable import BatteryWarn

/// Offscreen rendering shared by the README and the App Store screenshots
enum ScreenshotSupport {
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../..")
    }

    /// Where to write, or a skip when the variable is not set (normal test runs)
    static func outputDirectory(fromEnvironment variable: String) throws -> URL {
        guard let path = ProcessInfo.processInfo.environment[variable] else {
            throw XCTSkip("Set \(variable) to render screenshots")
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// The test process has no app bundle, so load the icon the app will ship with
    static func appIcon() throws -> NSImage {
        try XCTUnwrap(NSImage(contentsOf: repositoryRoot.appendingPathComponent("AppIcon.png")))
    }

    /// Likewise for the version shown in the footer
    static func bundleVersion() throws -> String {
        let plistURL = repositoryRoot.appendingPathComponent("BatteryWarn/Info.plist")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), format: nil)
        return try XCTUnwrap((plist as? [String: Any])?["CFBundleShortVersionString"] as? String)
    }

    /// A monitor on battery with fixed sample data, backed by throwaway defaults
    static func sampleMonitor(in testCase: XCTestCase) throws -> BatteryMonitor {
        let suite = "ScreenshotTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        testCase.addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }

        return BatteryMonitor(defaults: defaults, readPowerSource: {
            BatteryReading(description: [
                kIOPSCurrentCapacityKey: 64,
                kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
                kIOPSIsChargingKey: false,
                kIOPSTimeToEmptyKey: 312
            ])
        })
    }

    /// A made-up desktop, already blurred: wallpaper with two windows on it.
    /// Blurred with Core Image, because SwiftUI's blur does not show up in an offscreen render.
    static func desktopStandIn(size: CGSize) throws -> NSImage {
        let desktop = NSImage(size: size, flipped: false) { rect in
            NSGradient(colors: [
                NSColor(red: 0.16, green: 0.32, blue: 0.62, alpha: 1),
                NSColor(red: 0.44, green: 0.30, blue: 0.62, alpha: 1)
            ])?.draw(in: rect, angle: -35)

            NSColor(white: 0.96, alpha: 1).setFill()
            NSBezierPath(roundedRect: CGRect(x: 170, y: 280, width: 720, height: 460), xRadius: 12, yRadius: 12).fill()

            NSColor(white: 0.14, alpha: 1).setFill()
            NSBezierPath(roundedRect: CGRect(x: 790, y: 110, width: 520, height: 380), xRadius: 12, yRadius: 12).fill()
            return true
        }

        let source = try XCTUnwrap(desktop.tiffRepresentation.flatMap(CIImage.init(data:)))
        let blurred = source.clampedToExtent().applyingGaussianBlur(sigma: 60).cropped(to: source.extent)
        let rendered = try XCTUnwrap(CIContext().createCGImage(blurred, from: source.extent))
        return NSImage(cgImage: rendered, size: size)
    }

    /// A window showing the overlay as it covers a screen of the given size
    static func overlayWindow(_ model: OverlayModel, size: CGSize) throws -> NSWindow {
        // The overlay blurs and dims the screen behind it; stand in for that screen
        let desktop = try desktopStandIn(size: size)
        let view = ZStack {
            Image(nsImage: desktop)
                .resizable()
            // The real blur material darkens what it blurs
            Color.black.opacity(0.35)
            OverlayView(model: model, blursScreen: false)
        }
        .frame(width: size.width, height: size.height)

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: view)
        return window
    }

    /// Draws the view and its subviews into a bitmap, after giving SwiftUI `settleTime` to lay out.
    /// Without a scale the bitmap has the pixel density of the screen.
    static func bitmap(of view: NSView, scale: CGFloat? = nil, settleTime: TimeInterval = 0.5) throws -> NSBitmapImageRep {
        _ = NSApplication.shared
        view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(settleTime))

        let bitmap: NSBitmapImageRep
        if let scale {
            bitmap = try XCTUnwrap(NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int((view.bounds.width * scale).rounded()),
                pixelsHigh: Int((view.bounds.height * scale).rounded()),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ))
            bitmap.size = view.bounds.size
        } else {
            bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }

    static func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: url)
    }
}
