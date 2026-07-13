import AppKit

// Renders the Riffle app icon into a .iconset directory (PNGs at every size
// macOS wants). Run from the project root:
//
//   swift Tools/GenerateIcon.swift Riffle.iconset
//   iconutil -c icns Riffle.iconset -o Resources/Riffle.icns
//
// The artwork is drawn vectorially at each output size so it stays crisp down
// to 16pt: a fanned stack of "window" cards on a blue→indigo squircle, evoking
// riffling through windows.

func color(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a).cgColor
}

func draw(in cg: CGContext, size: CGFloat) {
    let k = size / 1024 // everything is authored on a 1024 grid

    // Rounded-square base, following Apple's ~10% margin / squircle look.
    let inset = 100 * k
    let side = size - inset * 2
    let base = CGRect(x: inset, y: inset, width: side, height: side)
    let radius = side * 0.2237
    let squircle = CGPath(roundedRect: base, cornerWidth: radius, cornerHeight: radius, transform: nil)

    cg.saveGState()
    cg.addPath(squircle)
    cg.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(72, 140, 255), color(124, 77, 255)] as CFArray,
        locations: [0, 1]
    )!
    // Diagonal, top-left (light blue) to bottom-right (indigo).
    cg.drawLinearGradient(
        gradient,
        start: CGPoint(x: base.minX, y: base.maxY),
        end: CGPoint(x: base.maxX, y: base.minY),
        options: []
    )
    // Soft sheen across the top third for a little depth.
    let sheen = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(255, 255, 255, 0.18), color(255, 255, 255, 0)] as CFArray,
        locations: [0, 1]
    )!
    cg.drawLinearGradient(
        sheen,
        start: CGPoint(x: base.midX, y: base.maxY),
        end: CGPoint(x: base.midX, y: base.midY),
        options: []
    )
    cg.restoreGState()

    // Fanned window cards. Back-to-front so the front one sits on top.
    let cx = size / 2, cy = size / 2
    let cardW = 470 * k, cardH = 360 * k, cardR = 46 * k
    struct Card { let angle: CGFloat; let dx: CGFloat; let dy: CGFloat; let alpha: CGFloat; let chrome: Bool }
    let cards = [
        Card(angle: -15, dx: -78 * k, dy: 26 * k, alpha: 0.55, chrome: false),
        Card(angle: -1, dx: -6 * k, dy: 6 * k, alpha: 0.80, chrome: false),
        Card(angle: 13, dx: 70 * k, dy: -20 * k, alpha: 1.0, chrome: true),
    ]

    for card in cards {
        cg.saveGState()
        cg.translateBy(x: cx + card.dx, y: cy + card.dy)
        cg.rotate(by: card.angle * .pi / 180)
        let rect = CGRect(x: -cardW / 2, y: -cardH / 2, width: cardW, height: cardH)
        let path = CGPath(roundedRect: rect, cornerWidth: cardR, cornerHeight: cardR, transform: nil)

        cg.setShadow(offset: CGSize(width: 0, height: -10 * k), blur: 34 * k, color: color(20, 24, 60, 0.28))
        cg.addPath(path)
        cg.setFillColor(color(255, 255, 255, card.alpha))
        cg.fillPath()

        if card.chrome {
            cg.setShadow(offset: .zero, blur: 0, color: nil)
            // Traffic-light dots along the title bar.
            let dotR = 17 * k
            let dotY = cardH / 2 - 48 * k
            let dots = [color(255, 95, 87), color(254, 188, 46), color(40, 200, 64)]
            for (i, c) in dots.enumerated() {
                let dotX = -cardW / 2 + 52 * k + CGFloat(i) * 52 * k
                cg.addPath(CGPath(ellipseIn: CGRect(x: dotX - dotR, y: dotY - dotR, width: dotR * 2, height: dotR * 2), transform: nil))
                cg.setFillColor(c)
                cg.fillPath()
            }
            // A couple of faint content lines below the title bar.
            let lineColor = color(124, 77, 255, 0.16)
            let lineX = -cardW / 2 + 52 * k
            let lineH = 26 * k
            for (i, w) in [cardW - 104 * k, (cardW - 104 * k) * 0.62].enumerated() {
                let lineY = cardH / 2 - 150 * k - CGFloat(i) * 58 * k
                cg.addPath(CGPath(roundedRect: CGRect(x: lineX, y: lineY, width: w, height: lineH), cornerWidth: lineH / 2, cornerHeight: lineH / 2, transform: nil))
                cg.setFillColor(lineColor)
                cg.fillPath()
            }
        }
        cg.restoreGState()
    }
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    ctx.cgContext.interpolationQuality = .high
    draw(in: ctx.cgContext, size: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Riffle.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, pixels) in entries {
    let data = png(pixels: pixels)
    try! data.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
}
print("Wrote \(entries.count) images to \(outDir)")
