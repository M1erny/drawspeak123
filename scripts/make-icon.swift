// Renders the Drawspeak app icon: a 1024x1024 opaque PNG (no alpha channel).
// Usage: swift scripts/make-icon.swift <out.png>
// Motif "Pencil Wave": a white waveform whose centre bar is a coral pencil, on a flat
// near-black ground (the same ground as the Apassy icon; the coral is the annotation
// colour of the app). No text; the shapes stay legible at 29 px.
// Coordinates below are SVG-style (origin top left, y down) on a 1024 grid.
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

let ground = rgb(0x0E1820)
let coral = rgb(0xFF5A6E)
let white = rgb(0xFFFFFF)

let space = CGColorSpace(name: CGColorSpace.sRGB)!
// noneSkipLast: 32-bit pixels without an alpha channel, so the PNG is opaque.
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("cannot create bitmap context")
}
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

// Flip to a y-down system so the numbers match the SVG source of the design.
ctx.translateBy(x: 0, y: s)
ctx.scaleBy(x: 1, y: -1)

// 1. Flat ground.
ctx.setFillColor(ground)
ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

// 2. Waveform: four white bars (centre x, top y, bottom y of the centre line), round caps.
let barWidth: CGFloat = 78
let bars: [(x: CGFloat, y1: CGFloat, y2: CGFloat)] = [
    (272, 449, 491), (392, 359, 581), (632, 359, 581), (752, 449, 491),
]
ctx.setStrokeColor(white)
ctx.setLineWidth(barWidth)
ctx.setLineCap(.round)
for b in bars {
    ctx.move(to: CGPoint(x: b.x, y: b.y1))
    ctx.addLine(to: CGPoint(x: b.x, y: b.y2))
    ctx.strokePath()
}

// 3. The coral pencil: a rounded top, a straight body and a pointed tip.
let k: CGFloat = 0.5523 * 39 // quarter-circle control offset for a radius of 39
let pencil = CGMutablePath()
pencil.move(to: CGPoint(x: 473, y: 289))
pencil.addCurve(to: CGPoint(x: 512, y: 250), control1: CGPoint(x: 473, y: 289 - k), control2: CGPoint(x: 512 - k, y: 250))
pencil.addCurve(to: CGPoint(x: 551, y: 289), control1: CGPoint(x: 512 + k, y: 250), control2: CGPoint(x: 551, y: 289 - k))
pencil.addLine(to: CGPoint(x: 551, y: 690))
pencil.addLine(to: CGPoint(x: 512, y: 822))
pencil.addLine(to: CGPoint(x: 473, y: 690))
pencil.closeSubpath()
ctx.addPath(pencil)
ctx.setFillColor(coral)
ctx.fillPath()

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("cannot create image destination")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("cannot write PNG") }
print("wrote \(outURL.path) \(image.width)x\(image.height) alphaInfo=\(image.alphaInfo.rawValue)")
