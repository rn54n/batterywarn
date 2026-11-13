#!/usr/bin/env swift
//
// Renders the BatteryWarn app icon from code, so it can be regenerated and
// tweaked without a design tool.
//
//   swift scripts/make-icon.swift            # writes into the repo root
//   swift scripts/make-icon.swift <out-dir>  # writes somewhere else (previews)
//
// Output: AppIcon.png (1024 px), AppIcon.iconset/ and AppIcon.icns.

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Layout

struct Shadow {
    var offset: CGFloat
    var blur: CGFloat
    var alpha: CGFloat
}

/// The exclamation mark inside the battery.
struct Mark {
    var stem: CGRect
    var stemBottomWidth: CGFloat
    var dot: CGRect
    /// nil draws fully round ends; small sizes use a fixed radius to stay crisp.
    var cornerRadius: CGFloat?
}

/// Where every part of the icon sits, in pixels of the rendered size with y
/// pointing down. Edges land on whole pixels so they stay crisp at every size.
struct Layout {
    var plate: CGRect
    var plateRadius: CGFloat
    var plateShadow: Shadow?
    /// Width of the light rim along the plate edge, 0 for none.
    var rim: CGFloat

    var body: CGRect
    var bodyRadius: CGFloat
    var stroke: CGFloat
    var pole: CGRect
    var poleRadius: CGFloat
    var bar: CGRect
    var barRadius: CGFloat
    var mark: Mark?
    var glyphShadow: Shadow?

    static func forSize(_ n: Int) -> Layout {
        switch n {
        case 16: return small16
        case 32: return small32
        default: return scaled(n)
        }
    }

    /// The master drawing, defined on Apple's 1024 px macOS icon grid
    /// (824 px plate, 100 px margin) and scaled to `n` pixels.
    static func scaled(_ n: Int) -> Layout {
        let size = CGFloat(n)
        let s = size / 1024
        func px(_ v: CGFloat) -> CGFloat { max(1, (v * s).rounded()) }
        // Rounds `v` so that it can be centred on whole pixels inside `outer`.
        func centred(_ v: CGFloat, in outer: CGFloat) -> CGFloat {
            let r = px(v)
            return (outer - r).truncatingRemainder(dividingBy: 2) == 0 ? r : r + 1
        }

        let plateSide = centred(824, in: size)
        let plateInset = (size - plateSide) / 2
        let plate = CGRect(x: plateInset, y: plateInset, width: plateSide, height: plateSide)

        let stroke = px(44)
        let bodyW = px(500)
        let bodyH = centred(290, in: size)
        let gap = px(14)
        let poleW = px(40)
        let poleH = centred(118, in: bodyH)

        // Centre the whole glyph, then nudge it right: the pole carries little
        // visual weight, so a bounding-box centre reads as shifted to the left.
        let totalW = bodyW + gap + poleW
        let x0 = ((size - totalW) / 2 + 6 * s).rounded()
        let y0 = (size - bodyH) / 2
        let body = CGRect(x: x0, y: y0, width: bodyW, height: bodyH)
        let pole = CGRect(x: body.maxX + gap, y: body.midY - poleH / 2, width: poleW, height: poleH)

        let inner = body.insetBy(dx: stroke, dy: stroke)
        let barInset = px(22)
        let bar = CGRect(
            x: inner.minX + barInset,
            y: inner.minY + barInset,
            width: px(76),
            height: inner.height - 2 * barInset
        )

        // The mark shares the bar's top and bottom line and sits in the middle
        // of the empty part of the battery.
        let stemW = px(42)
        let dotD = px(44)
        let markGap = px(22)
        let markX = (bar.maxX + inner.maxX) / 2
        let stem = CGRect(
            x: (markX - stemW / 2).rounded(),
            y: bar.minY,
            width: stemW,
            height: bar.height - markGap - dotD
        )
        let dot = CGRect(x: stem.midX - dotD / 2, y: bar.maxY - dotD, width: dotD, height: dotD)

        return Layout(
            plate: plate,
            plateRadius: plateSide * 0.225,
            plateShadow: Shadow(offset: 10 * s, blur: 22 * s, alpha: 0.30),
            rim: max(1, 3 * s),
            body: body,
            bodyRadius: 84 * s,
            stroke: stroke,
            pole: pole,
            poleRadius: 16 * s,
            bar: bar,
            barRadius: 16 * s,
            mark: Mark(
                stem: stem,
                stemBottomWidth: n >= 128 ? stemW * 0.68 : stemW,
                dot: dot,
                cornerRadius: nil
            ),
            glyphShadow: Shadow(offset: 6 * s, blur: 16 * s, alpha: 0.16)
        )
    }

    /// 32 px, drawn by hand on the pixel grid: heavier outline, blocky mark.
    static let small32 = Layout(
        plate: CGRect(x: 3, y: 3, width: 26, height: 26),
        plateRadius: 5.9,
        plateShadow: Shadow(offset: 0.5, blur: 1.5, alpha: 0.25),
        rim: 0,
        body: CGRect(x: 6, y: 9, width: 17, height: 13),
        bodyRadius: 3.5,
        stroke: 2,
        pole: CGRect(x: 24, y: 13, width: 2, height: 5),
        poleRadius: 0.75,
        bar: CGRect(x: 9, y: 12, width: 3, height: 7),
        barRadius: 0.75,
        mark: Mark(
            stem: CGRect(x: 16, y: 12, width: 2, height: 4),
            stemBottomWidth: 2,
            dot: CGRect(x: 16, y: 17, width: 2, height: 2),
            cornerRadius: 0.5
        ),
        glyphShadow: nil
    )

    /// 16 px: just the low battery, no mark. There is no room for both.
    static let small16 = Layout(
        plate: CGRect(x: 1, y: 1, width: 14, height: 14),
        plateRadius: 3.2,
        plateShadow: nil,
        rim: 0,
        body: CGRect(x: 3, y: 5, width: 10, height: 6),
        bodyRadius: 1.75,
        stroke: 1,
        pole: CGRect(x: 13, y: 7, width: 1, height: 2),
        poleRadius: 0,
        bar: CGRect(x: 5, y: 7, width: 2, height: 2),
        barRadius: 0,
        mark: nil,
        glyphShadow: nil
    )
}

// MARK: - Drawing

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: sRGB, components: [r, g, b, a])!
}

let plateTop = color(1.00, 0.38, 0.31)
let plateBottom = color(0.86, 0.06, 0.15)

func roundedPath(_ rect: CGRect, radius: CGFloat, continuous: Bool = false) -> CGPath {
    let r = max(0, min(radius, rect.width / 2, rect.height / 2))
    if continuous {
        return RoundedRectangle(cornerRadius: r, style: .continuous).path(in: rect).cgPath
    }
    return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

func gradient(_ stops: [(CGColor, CGFloat)]) -> CGGradient {
    CGGradient(
        colorsSpace: sRGB,
        colors: stops.map { $0.0 } as CFArray,
        locations: stops.map { $0.1 }
    )!
}

func withShadow(_ shadow: Shadow?, in ctx: CGContext, _ draw: () -> Void) {
    ctx.saveGState()
    if let shadow {
        // Shadow offsets ignore the flipped CTM: negative height is down.
        ctx.setShadow(
            offset: CGSize(width: 0, height: -shadow.offset),
            blur: shadow.blur,
            color: color(0, 0, 0, shadow.alpha)
        )
    }
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    draw()
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

func drawPlate(_ l: Layout, in ctx: CGContext) {
    let path = roundedPath(l.plate, radius: l.plateRadius, continuous: true)
    let top = CGPoint(x: l.plate.midX, y: l.plate.minY)
    let bottom = CGPoint(x: l.plate.midX, y: l.plate.maxY)

    withShadow(l.plateShadow, in: ctx) {
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(
            gradient([(plateTop, 0), (plateBottom, 1)]),
            start: top, end: bottom, options: []
        )
        // A soft glow from above keeps the red from looking flat.
        ctx.drawRadialGradient(
            gradient([(color(1, 1, 1, 0.10), 0), (color(1, 1, 1, 0), 1)]),
            startCenter: CGPoint(x: l.plate.midX, y: l.plate.minY - l.plate.height * 0.15),
            startRadius: 0,
            endCenter: CGPoint(x: l.plate.midX, y: l.plate.minY - l.plate.height * 0.15),
            endRadius: l.plate.height * 0.95,
            options: []
        )
    }

    guard l.rim > 0 else { return }
    // Light catching the top edge, a little shade along the bottom edge.
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.addPath(path)
    ctx.setLineWidth(l.rim * 2)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([
            (color(1, 1, 1, 0.30), 0),
            (color(1, 1, 1, 0), 0.42),
            (color(0, 0, 0, 0), 0.58),
            (color(0, 0, 0, 0.14), 1),
        ]),
        start: top, end: bottom, options: []
    )
    ctx.restoreGState()
}

func drawGlyph(_ l: Layout, in ctx: CGContext) {
    // Above a few pixels of radius the battery uses the same continuous
    // corners as the plate; below that plain arcs render cleaner.
    let continuous = l.bodyRadius >= 6

    withShadow(l.glyphShadow, in: ctx) {
        ctx.setFillColor(color(1, 1, 1))

        let inner = l.body.insetBy(dx: l.stroke, dy: l.stroke)
        ctx.addPath(roundedPath(l.body, radius: l.bodyRadius, continuous: continuous))
        ctx.addPath(roundedPath(inner, radius: l.bodyRadius - l.stroke, continuous: continuous))
        ctx.fillPath(using: .evenOdd)

        ctx.addPath(roundedPath(l.pole, radius: l.poleRadius))
        ctx.fillPath()

        ctx.addPath(roundedPath(l.bar, radius: l.barRadius))
        ctx.fillPath()

        guard let mark = l.mark else { return }
        if let r = mark.cornerRadius {
            ctx.addPath(roundedPath(mark.stem, radius: r))
            ctx.fillPath()
            ctx.addPath(roundedPath(mark.dot, radius: r))
            ctx.fillPath()
        } else {
            // A capsule that narrows towards the dot: two circles and the
            // trapezoid between them, filled one by one.
            let rt = mark.stem.width / 2
            let rb = mark.stemBottomWidth / 2
            let cx = mark.stem.midX
            let yt = mark.stem.minY + rt
            let yb = mark.stem.maxY - rb
            ctx.fillEllipse(in: CGRect(x: cx - rt, y: yt - rt, width: rt * 2, height: rt * 2))
            ctx.fillEllipse(in: CGRect(x: cx - rb, y: yb - rb, width: rb * 2, height: rb * 2))
            ctx.move(to: CGPoint(x: cx - rt, y: yt))
            ctx.addLine(to: CGPoint(x: cx + rt, y: yt))
            ctx.addLine(to: CGPoint(x: cx + rb, y: yb))
            ctx.addLine(to: CGPoint(x: cx - rb, y: yb))
            ctx.closePath()
            ctx.fillPath()
            ctx.fillEllipse(in: mark.dot)
        }
    }
}

func render(_ n: Int) -> CGImage {
    let ctx = CGContext(
        data: nil, width: n, height: n,
        bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // Flip to y-down so the layout reads top to bottom.
    ctx.translateBy(x: 0, y: CGFloat(n))
    ctx.scaleBy(x: 1, y: -1)

    let layout = Layout.forSize(n)
    drawPlate(layout, in: ctx)
    drawGlyph(layout, in: ctx)
    return ctx.makeImage()!
}

// MARK: - Output

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { fail("cannot create \(url.path)") }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) { fail("cannot write \(url.path)") }
}

let fm = FileManager.default
let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
let repoRoot = URL(fileURLWithPath: #filePath, relativeTo: cwd)
    .standardizedFileURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let outDir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1], relativeTo: cwd).standardizedFileURL
    : repoRoot
let iconset = outDir.appendingPathComponent("AppIcon.iconset")

do {
    try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
} catch {
    fail("cannot create \(iconset.path): \(error.localizedDescription)")
}

// The names iconutil expects, with the pixel size each one holds.
let iconsetFiles: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

var rendered: [Int: CGImage] = [:]
for file in iconsetFiles {
    let image = rendered[file.pixels] ?? render(file.pixels)
    rendered[file.pixels] = image
    writePNG(image, to: iconset.appendingPathComponent("\(file.name).png"))
}
writePNG(rendered[1024]!, to: outDir.appendingPathComponent("AppIcon.png"))

let icns = outDir.appendingPathComponent("AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
do {
    try iconutil.run()
} catch {
    fail("cannot run iconutil: \(error.localizedDescription)")
}
iconutil.waitUntilExit()
if iconutil.terminationStatus != 0 { fail("iconutil exited with \(iconutil.terminationStatus)") }

print("Wrote AppIcon.png, AppIcon.iconset and AppIcon.icns to \(outDir.path)")
