// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

// Generates all icon assets:
// - the app iconset and .icns from the exported Default rendition of the
//   adaptive source (Resources/Brand/AppIcon-Default.png)
// - BrandMark from the mark master (Resources/Brand/logo.png), and the menu
//   bar template glyph from its heavier cut (Resources/Brand/logo-menubar.png),
//   whose lines stay visible at 15 points where the master's would vanish
// AppIcon-Default.png is a hand-exported twin of Resources/Brand/AppIcon.icon;
// re-export it whenever the Icon Composer project changes. The build cannot read
// .icon bundles directly: actool exists only inside full Xcode 26, and the
// supported local floor is Command Line Tools alone.
import AppKit

// Current macOS misreads PNG payloads in the legacy small chunks. It downsamples
// ic07 for 1x and uses the explicit ic11/ic12 representations on Retina displays.
let iconSizes: [(name: String, px: Int, icnsType: String?)] = [
    ("icon_16x16", 16, nil), ("icon_16x16@2x", 32, "ic11"),
    ("icon_32x32", 32, nil), ("icon_32x32@2x", 64, "ic12"),
    ("icon_128x128", 128, "ic07"), ("icon_128x128@2x", 256, "ic13"),
    ("icon_256x256", 256, "ic08"), ("icon_256x256@2x", 512, "ic14"),
    ("icon_512x512", 512, "ic09"), ("icon_512x512@2x", 1024, "ic10"),
]

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let projectDir = scriptDir.deletingLastPathComponent()
let logoPath = projectDir.appendingPathComponent("Resources/Brand/logo.png").path

guard let logo = NSImage(contentsOfFile: logoPath),
      let logoTIFF = logo.tiffRepresentation,
      let logoRep = NSBitmapImageRep(data: logoTIFF)
else {
    print("could not load \(logoPath)")
    exit(1)
}

let appIconPath = projectDir.appendingPathComponent("Resources/Brand/AppIcon-Default.png").path
guard let appIconMaster = NSImage(contentsOfFile: appIconPath) else {
    print("could not load \(appIconPath)")
    exit(1)
}

/// Bounding box of visible (non-transparent) pixels, so the mark can be
/// centered optically regardless of padding in the source file.
func contentBounds(of rep: NSBitmapImageRep) -> CGRect {
    var minX = rep.pixelsWide, minY = rep.pixelsHigh, maxX = 0, maxY = 0
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            if let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.05 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
    }
    guard maxX > minX, maxY > minY else {
        return CGRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh)
    }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

/// The visible part of a master, in NSImage's bottom-up drawing space.
func trimmedRect(of rep: NSBitmapImageRep) -> CGRect {
    let bounds = contentBounds(of: rep)
    // NSImage draws bottom-up while colorAt() is top-down — flip Y for drawing.
    return CGRect(x: bounds.minX, y: CGFloat(rep.pixelsHigh) - bounds.maxY,
                  width: bounds.width, height: bounds.height)
}
let sourceRect = trimmedRect(of: logoRep)

let menuBarLogoPath = projectDir.appendingPathComponent("Resources/Brand/logo-menubar.png").path
let menuBarLogo: NSImage
let menuBarSourceRect: CGRect
if let heavy = NSImage(contentsOfFile: menuBarLogoPath), let tiff = heavy.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff) {
    menuBarLogo = heavy
    menuBarSourceRect = trimmedRect(of: rep)
} else {
    menuBarLogo = logo
    menuBarSourceRect = sourceRect
}

func bitmapCanvas(_ px: Int, _ py: Int) -> NSBitmapImageRep? {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: py,
                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                     isPlanar: false, colorSpaceName: .deviceRGB,
                     bytesPerRow: 0, bitsPerPixel: 0)
}

/// Draws the trimmed mark fitted into `target`, preserving aspect ratio.
func drawMark(into target: CGRect, image: NSImage = logo, source: CGRect = sourceRect) {
    let scale = min(target.width / source.width, target.height / source.height)
    let size = CGSize(width: source.width * scale, height: source.height * scale)
    let rect = CGRect(x: target.midX - size.width / 2,
                      y: target.midY - size.height / 2,
                      width: size.width, height: size.height)
    image.draw(in: rect, from: source, operation: .sourceOver, fraction: 1,
               respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high.rawValue])
}

// MARK: - App icon

func renderAppIcon(px: Int) -> Data? {
    let size = CGFloat(px)
    guard let rep = bitmapCanvas(px, px), let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    rep.size = NSSize(width: size, height: size)

    // Every renderer in MakeIcon.swift focuses the graphics context before
    // drawing; without this the draws land nowhere and the PNGs come out empty.
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    // The exported Default rendition is the finished icon design: background,
    // layering and system-grid margins are baked in, so it maps onto the canvas
    // 1:1 instead of being re-framed like the old mark-on-squircle composite.
    // Source rect = the ENTIRE master, in the MASTER's coordinate space
    // (appIconMaster.size), never the target's — a size-sized source rect would
    // crop the bottom-left corner of the 1024x1024 master instead of scaling.
    // (This SDK's draw(in:from:...) types from: as non-optional NSRect, so
    // full-source must be spelled out rather than passed as nil.)
    appIconMaster.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                       from: NSRect(origin: .zero, size: appIconMaster.size),
                       operation: .sourceOver, fraction: 1,
                       respectFlipped: false,
                       hints: [.interpolation: NSImageInterpolation.high.rawValue])
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

// MARK: - Menu bar glyph (template)

// Sized from the height and let the width follow. The mark is about as wide
// as it is tall, so it takes the full height menu bar symbols use.
let menuBarGlyphHeight: CGFloat = 15
// Symmetric top to bottom, so it sits centred.
let menuBarGlyphDrop: CGFloat = 0
// Taller than the mark needs: the same canvas holds the compact Keep Awake
// symbols. Keep in sync with BlackHoleGlyph.pointSize in
// Sources/Vorssaint/App/StatusItemController.swift; `--selftest` enforces it.
let menuBarCanvas = (width: 26, height: 20)

func renderMenuBarIcon(scale: Int) -> Data? {
    let width = menuBarCanvas.width * scale, height = menuBarCanvas.height * scale
    guard let rep = bitmapCanvas(width, height), let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    rep.size = NSSize(width: menuBarCanvas.width, height: menuBarCanvas.height)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    // Height-limited target spanning the full canvas width: drawMark keeps the
    // aspect ratio and centers, landing the mark at about 14×15 pt. Coordinates
    // are bottom-up, so dropping it lowers y.
    let ink = menuBarGlyphHeight * CGFloat(scale)
    let y = (CGFloat(height) - ink) / 2 - menuBarGlyphDrop * CGFloat(scale)
    drawMark(into: CGRect(x: 0, y: y, width: CGFloat(width), height: ink),
             image: menuBarLogo, source: menuBarSourceRect)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

func appendFourCC(_ value: String, to data: inout Data) {
    data.append(contentsOf: value.utf8)
}

func appendUInt32BE(_ value: Int, to data: inout Data) {
    let clamped = UInt32(value)
    data.append(UInt8((clamped >> 24) & 0xff))
    data.append(UInt8((clamped >> 16) & 0xff))
    data.append(UInt8((clamped >> 8) & 0xff))
    data.append(UInt8(clamped & 0xff))
}

func writeICNS(entries: [(type: String, data: Data)], to url: URL) throws {
    let totalLength = 8 + entries.reduce(0) { $0 + 8 + $1.data.count }
    var icns = Data()
    appendFourCC("icns", to: &icns)
    appendUInt32BE(totalLength, to: &icns)
    for entry in entries {
        appendFourCC(entry.type, to: &icns)
        appendUInt32BE(8 + entry.data.count, to: &icns)
        icns.append(entry.data)
    }
    try icns.write(to: url)
}

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
var icnsEntries: [(type: String, data: Data)] = []
for (name, px, icnsType) in iconSizes {
    guard let data = renderAppIcon(px: px) else {
        print("failed to render \(name)")
        exit(1)
    }
    try data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    if let icnsType {
        icnsEntries.append((type: icnsType, data: data))
    }
}
try writeICNS(entries: icnsEntries, to: URL(fileURLWithPath: "\(outDir)/../AppIcon.icns"))

for scale in [1, 2] {
    guard let data = renderMenuBarIcon(scale: scale) else {
        print("failed to render menu bar icon @\(scale)x")
        exit(1)
    }
    let suffix = scale == 1 ? "" : "@2x"
    try data.write(to: URL(fileURLWithPath: "\(outDir)/../MenuBarIcon\(suffix).png"))
}

// Trimmed mark for in-app use (panel header, onboarding, About).
let markWidth = 640
let markHeight = Int(CGFloat(markWidth) * sourceRect.height / sourceRect.width)
if let rep = bitmapCanvas(markWidth, markHeight), let ctx = NSGraphicsContext(bitmapImageRep: rep) {
    rep.size = NSSize(width: markWidth, height: markHeight)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    drawMark(into: CGRect(x: 0, y: 0, width: CGFloat(markWidth), height: CGFloat(markHeight)))
    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try data.write(to: URL(fileURLWithPath: "\(outDir)/../BrandMark.png"))
    }
}
print("iconset written to \(outDir)")
