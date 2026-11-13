import XCTest
import SwiftUI
import UniformTypeIdentifiers
@testable import BatteryWarn

/// Renders the Mac App Store screenshots: the real views inside a caption frame, 2880 x 1800.
/// Skipped in normal test runs; use scripts/make-appstore-screenshots.sh to regenerate.
final class AppStoreScreenshotTests: XCTestCase {
    /// 16:10 in points; rendered at 2x this is the largest size the App Store takes
    private let canvas = CGSize(width: 1440, height: 900)
    private let screenSize = CGSize(width: 1440, height: 900)
    private var directory: URL!

    /// Skip before anything is rendered, so normal test runs lose no time here
    override func setUpWithError() throws {
        directory = try ScreenshotSupport.outputDirectory(fromEnvironment: "APPSTORE_SCREENSHOT_DIR")
    }

    @MainActor
    func testShot1Warning() throws {
        let model = OverlayModel(batteryLevel: 9, isCritical: false, minutesRemaining: 17, threshold: 10)

        try write(
            OverlayShot(
                caption: StoreCaption(
                    eyebrow: "BATTERYWARN",
                    headline: "A warning you can’t miss",
                    subline: "When the battery reaches your limit, the whole screen says so."
                ),
                screen: try overlayScreen(model)
            ),
            to: "01-warning.jpg"
        )
    }

    @MainActor
    func testShot2Threshold() throws {
        try write(
            SettingsShot(
                caption: StoreCaption(
                    eyebrow: "YOUR LIMIT",
                    headline: "Drag to set\nyour limit",
                    subline: "Move the marker on the battery,\nanywhere from 5% to 99%.",
                    alignment: .leading
                ),
                window: try settingsWindow(appearance: .aqua),
                showsDragCursor: true
            ),
            to: "02-threshold.jpg"
        )
    }

    @MainActor
    func testShot3Critical() throws {
        let model = OverlayModel(batteryLevel: 4, isCritical: true, minutesRemaining: 6, threshold: 10)

        try write(
            OverlayShot(
                caption: StoreCaption(
                    eyebrow: "CRITICAL AT 5%",
                    headline: "Critical means critical",
                    subline: "At 5% and below, dismissing takes a three-second hold on ESC."
                ),
                screen: try overlayScreen(model)
            ),
            to: "03-critical.jpg"
        )
    }

    @MainActor
    func testShot4NoDismissing() throws {
        let model = OverlayModel(batteryLevel: 7, isCritical: false, minutesRemaining: 12, threshold: 10, allowsDismiss: false)

        try write(
            OverlaySideShot(
                caption: StoreCaption(
                    eyebrow: "ALLOW DISMISSING: OFF",
                    headline: "Or make it stay\nuntil you plug in",
                    subline: "Turn off Allow Dismissing and\nthe warning keeps the screen\nuntil power is connected.",
                    alignment: .leading
                ),
                screen: try overlayScreen(model)
            ),
            to: "04-no-dismissing.jpg"
        )
    }

    @MainActor
    func testShot5Appearance() throws {
        try write(
            AppearanceShot(
                caption: StoreCaption(
                    eyebrow: "NATIVE MACOS APP",
                    headline: "At home in light and dark",
                    subline: "A small menu bar app. Follows the system appearance, or the one you pick."
                ),
                lightWindow: try settingsWindow(appearance: .aqua),
                darkWindow: try settingsWindow(appearance: .darkAqua)
            ),
            to: "05-appearance.jpg"
        )
    }

    // MARK: - App Views

    /// The full-screen warning as it looks on a display, caught at the bright end of its pulse
    private func overlayScreen(_ model: OverlayModel) throws -> NSImage {
        let window = try ScreenshotSupport.overlayWindow(model, size: screenSize)
        let view = try XCTUnwrap(window.contentView)

        return image(from: try ScreenshotSupport.bitmap(of: view, scale: 2, settleTime: model.isCritical ? 1.2 : 2.0))
    }

    /// The Settings window with its title bar, drawn the way it looks while in use
    private func settingsWindow(appearance: NSAppearance.Name) throws -> NSImage {
        let monitor = try ScreenshotSupport.sampleMonitor(in: self)
        monitor.threshold = SettingsShot.threshold

        let view = SettingsView(
            loginItemAvailable: true,
            appVersion: try ScreenshotSupport.bundleVersion(),
            appIcon: try ScreenshotSupport.appIcon()
        )
        .environmentObject(monitor)

        let window = SettingsWindow.make(rootView: view)
        window.appearance = NSAppearance(named: appearance)
        showAsFrontmost(window)

        let frameView = try XCTUnwrap(window.contentView?.superview)
        return image(from: try ScreenshotSupport.bitmap(of: frameView, scale: 2))
    }

    /// A window that is not on screen draws its controls and close button greyed out, as if in the background.
    /// AppKit has no public switch for this, so ask through its own private one and
    /// leave the window as it is where that is missing.
    private func showAsFrontmost(_ window: NSWindow) {
        let acquireKeyAppearance = NSSelectorFromString("acquireKeyAppearance")
        if window.responds(to: acquireKeyAppearance) {
            window.perform(acquireKeyAppearance)
        }
    }

    private func image(from bitmap: NSBitmapImageRep) -> NSImage {
        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return image
    }

    // MARK: - Output

    @MainActor
    private func write(_ shot: some View, to name: String) throws {
        let renderer = ImageRenderer(content: shot.frame(width: canvas.width, height: canvas.height))
        renderer.scale = 2
        let rendered = try XCTUnwrap(renderer.cgImage)
        XCTAssertEqual(rendered.width, 2880)
        XCTAssertEqual(rendered.height, 1800)

        // App Store Connect does not take screenshots with an alpha channel
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: rendered.width,
            height: rendered.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.draw(rendered, in: CGRect(x: 0, y: 0, width: rendered.width, height: rendered.height))
        let opaque = try XCTUnwrap(context.makeImage())

        // JPEG, because the gradients compress badly as PNG
        let url = directory.appendingPathComponent(name)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        let quality = [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary
        CGImageDestinationAddImage(destination, opaque, quality)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}

// MARK: - Caption Frame

private enum StoreStyle {
    // The warning light of the overlay, and its softer tint for small text
    static let glow = Color(red: 1.0, green: 0.23, blue: 0.19)
    static let glowText = Color(red: 1.0, green: 0.48, blue: 0.43)
}

/// Eyebrow, headline and one line of explanation
private struct StoreCaption: View {
    let eyebrow: String
    let headline: String
    let subline: String
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(eyebrow)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .tracking(4)
                .foregroundColor(StoreStyle.glowText)

            Text(headline)
                .font(.system(size: alignment == .center ? 58 : 64, weight: .bold, design: .rounded))
                .tracking(-1.2)
                .lineSpacing(-4)
                .foregroundColor(.white)
                .padding(.top, 16)

            Text(subline)
                .font(.system(size: 23, weight: .regular))
                .lineSpacing(5)
                .foregroundColor(.white.opacity(0.62))
                .padding(.top, alignment == .center ? 14 : 22)
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .fixedSize()
    }
}

/// A cool near-black, so the red of the app is the only warm thing in the picture
private struct StoreBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.075, blue: 0.125), Color(red: 0.025, green: 0.03, blue: 0.055)],
                startPoint: .top,
                endPoint: .bottom
            )

            // A lift behind the caption keeps the dark from going flat
            RadialGradient(
                colors: [Color(red: 0.36, green: 0.48, blue: 0.95).opacity(0.2), .clear],
                center: UnitPoint(x: 0.5, y: -0.1),
                startRadius: 0,
                endRadius: 900
            )
        }
    }
}

// MARK: - Shots

/// Caption on top, the full-screen warning on a display below
private struct OverlayShot: View {
    let caption: StoreCaption
    let screen: NSImage

    var body: some View {
        ZStack {
            StoreBackdrop()

            VStack(spacing: 0) {
                caption
                    .padding(.top, 52)

                Spacer(minLength: 0)

                DisplayFrame(screen: screen, screenSize: CGSize(width: 960, height: 600))
                    .padding(.bottom, 36)
            }
        }
    }
}

/// Caption on the left, the full-screen warning on a larger display that runs off the right edge
private struct OverlaySideShot: View {
    let caption: StoreCaption
    let screen: NSImage

    var body: some View {
        ZStack(alignment: .topLeading) {
            StoreBackdrop()

            caption
                .frame(width: 500, height: 900, alignment: .leading)
                .offset(x: 140)

            DisplayFrame(screen: screen, screenSize: CGSize(width: 1040, height: 650))
                .offset(x: 680, y: 116)
        }
    }
}

/// A plain display: thin black bezel, nothing else
private struct DisplayFrame: View {
    let screen: NSImage
    let screenSize: CGSize

    var body: some View {
        Image(nsImage: screen)
            .resizable()
            .interpolation(.high)
            .frame(width: screenSize.width, height: screenSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(.black)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            )
            // The warning lights up the room around the display
            .shadow(color: StoreStyle.glow.opacity(0.45), radius: 70)
            .shadow(color: .black.opacity(0.5), radius: 30, y: 20)
    }
}

/// Caption on the left, the Settings window on the right
private struct SettingsShot: View {
    static let threshold = 20

    let caption: StoreCaption
    let window: NSImage
    var showsDragCursor = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            StoreBackdrop()

            caption
                .frame(width: 560, height: 900, alignment: .leading)
                .offset(x: 140)

            // Whole points, so the window keeps its exact pixels
            WindowImage(window: window)
                .overlay(alignment: .topLeading) {
                    if showsDragCursor {
                        dragCursor
                    }
                }
                .offset(x: 770, y: ((900 - window.size.height) / 2).rounded())
        }
    }

    /// The cursor the marker shows under the pointer, placed on the marker
    private var dragCursor: some View {
        // Same geometry as BatteryGaugeView: 24 pt window padding, 5 pt inset, 6 + 4 pt for the cap.
        // The bar sits 136 pt below the top of the window.
        let innerWidth = window.size.width - 48 - 10 - 10
        let markerX = 24 + 5 + innerWidth * CGFloat(Self.threshold) / 100
        let cursor = NSCursor.resizeLeftRight.image

        return Image(nsImage: cursor)
            .offset(x: markerX - cursor.size.width / 2, y: 136 - cursor.size.height / 2)
    }
}

/// Caption on top, the light and the dark Settings window side by side below
private struct AppearanceShot: View {
    let caption: StoreCaption
    let lightWindow: NSImage
    let darkWindow: NSImage

    var body: some View {
        ZStack {
            StoreBackdrop()

            VStack(spacing: 0) {
                caption
                    .padding(.top, 52)

                Spacer(minLength: 0)

                HStack(spacing: 48) {
                    WindowImage(window: lightWindow)
                    WindowImage(window: darkWindow)
                }
                .padding(.bottom, 78)
            }
        }
    }
}

/// A captured window at its own size, with what the window server adds on screen:
/// rounded corners, a hairline edge and a shadow
private struct WindowImage: View {
    let window: NSImage

    // Corner radius of a titled window without a toolbar on macOS 26
    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        Image(nsImage: window)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 1)
            .shadow(color: .black.opacity(0.5), radius: 34, y: 20)
    }
}
