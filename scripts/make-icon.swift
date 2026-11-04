// Renders the Drawspeak app icon: a 1024x1024 opaque PNG (no alpha channel).
// Usage: swift scripts/make-icon.swift <out.png>
// Motif: a screen card on a calm canvas, a red pencil loop marking part of it,
// and a speech-wave badge. No text; shapes stay legible at 40 px.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <out.png>\n".data(using: .utf8)!)
    exit(64)
}
let outURL = URL(fileURLWithPath: args[1])
let size = 1024
let s = CGFloat(size)

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
// noneSkipLast: 32-bit pixels without an alpha channel, so the PNG is opaque.
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("cannot create bitmap context")
}
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

// 1. Canvas background: soft off-white to blue-gray vertical gradient.
let bg = CGGradient(colorsSpace: space, colors: [rgb(0xF3F5F8), rgb(0xD9E0E8)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

// 2. Screen card with a soft shadow, header bar and content lines.
let card = CGRect(x: 132, y: 250, width: 680, height: 560)
let cardPath = CGPath(roundedRect: card, cornerWidth: 70, cornerHeight: 70, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 48, color: rgb(0x7D8A9C).copy(alpha: 0.45))
ctx.addPath(cardPath)
ctx.setFillColor(rgb(0xFFFFFF))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(cardPath)
ctx.clip()
ctx.setFillColor(rgb(0x3E4F66))
ctx.fill(CGRect(x: card.minX, y: card.maxY - 120, width: card.width, height: 120))
ctx.restoreGState()

func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: CGColor) {
    ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h),
                       cornerWidth: min(w, h) / 2, cornerHeight: min(w, h) / 2, transform: nil))
    ctx.setFillColor(color)
    ctx.fillPath()
}
let line = rgb(0xC5CEDA)
bar(card.minX + 64, card.maxY - 210, 420, 40, line)
bar(card.minX + 64, card.maxY - 290, 300, 40, line)
// A content block, the part the loop marks.
ctx.addPath(CGPath(roundedRect: CGRect(x: card.minX + 64, y: card.minY + 70, width: 330, height: 170),
                   cornerWidth: 28, cornerHeight: 28, transform: nil))
ctx.setFillColor(rgb(0xDCE3EC))
ctx.fillPath()

// 3. Red pencil loop: a slightly widening ellipse that overshoots its start, like a hand lasso.
let loop = CGMutablePath()
let center = CGPoint(x: 370, y: 410)
let rx: CGFloat = 250, ry: CGFloat = 160
let rot: CGFloat = -0.16
let start: CGFloat = 2.35
let sweep: CGFloat = 2 * .pi + 0.55
let steps = 240
for i in 0...steps {
    let t = start + sweep * CGFloat(i) / CGFloat(steps)
    let grow = 1 + 0.10 * CGFloat(i) / CGFloat(steps)
    let x0 = cos(t) * rx * grow, y0 = sin(t) * ry * grow
    let p = CGPoint(x: center.x + x0 * cos(rot) - y0 * sin(rot), y: center.y + x0 * sin(rot) + y0 * cos(rot))
    if i == 0 { loop.move(to: p) } else { loop.addLine(to: p) }
}
ctx.addPath(loop)
ctx.setStrokeColor(rgb(0xBD3048))
ctx.setLineWidth(48)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.strokePath()

// 4. Speech-wave badge: dark slate disc with a light ring and five rounded bars.
let badgeC = CGPoint(x: 770, y: 262)
let badgeR: CGFloat = 158
ctx.setFillColor(rgb(0xF3F5F8))
ctx.fillEllipse(in: CGRect(x: badgeC.x - badgeR - 20, y: badgeC.y - badgeR - 20,
                           width: 2 * (badgeR + 20), height: 2 * (badgeR + 20)))
ctx.setFillColor(rgb(0x2E3A4B))
ctx.fillEllipse(in: CGRect(x: badgeC.x - badgeR, y: badgeC.y - badgeR, width: 2 * badgeR, height: 2 * badgeR))
let heights: [CGFloat] = [70, 140, 200, 140, 70]
let bw: CGFloat = 30, gap: CGFloat = 22
let total = CGFloat(heights.count) * bw + CGFloat(heights.count - 1) * gap
for (i, h) in heights.enumerated() {
    let x = badgeC.x - total / 2 + CGFloat(i) * (bw + gap)
    bar(x, badgeC.y - h / 2, bw, h, rgb(0xFFFFFF))
}

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("cannot create image destination")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("cannot write PNG") }
print("wrote \(outURL.path) \(image.width)x\(image.height) alphaInfo=\(image.alphaInfo.rawValue)")
