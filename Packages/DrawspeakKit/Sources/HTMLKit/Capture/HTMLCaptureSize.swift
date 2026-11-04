import DrawspeakCore
import Foundation

/// CSS layout stays at the requested width; only raster resolution is reduced.
nonisolated struct HTMLCaptureSize: Sendable, Equatable {
    static let maximumHeightCSS = 8_000.0
    static let maximumPixels = 40_000_000
    /// Tallest raster WebKit is asked for in one snapshot. A single snapshot
    /// taller than the GPU texture limit (8192 px on the simulator) comes back
    /// fully black, so tall pages are captured in slices and stitched.
    static let maximumTilePixelHeight = 4_096

    let widthCSS: Double
    let heightCSS: Double
    let pixelWidth: Int
    let pixelHeight: Int

    init(viewport: Viewport, contentHeightCSS: Double) {
        widthCSS = Double(max(1, viewport.width))
        let height = contentHeightCSS.isFinite && contentHeightCSS > 0
            ? contentHeightCSS : Double(max(1, viewport.height))
        heightCSS = min(Self.maximumHeightCSS, ceil(height))
        let requestedScale = viewport.deviceScaleFactor.isFinite && viewport.deviceScaleFactor > 0
            ? viewport.deviceScaleFactor : 1
        let scale = min(requestedScale, sqrt(Double(Self.maximumPixels) / (widthCSS * heightCSS)))
        pixelWidth = max(1, Int(min(Double(Self.maximumPixels), floor(widthCSS * scale))))
        pixelHeight = max(1, min(Self.maximumPixels / pixelWidth, Int(floor(heightCSS * scale))))
    }

    /// Horizontal slices that cover the page top to bottom. Pixel edges are
    /// derived from CSS edges with one shared scale, so slices abut exactly.
    func tiles(maximumPixelHeight: Int = maximumTilePixelHeight) -> [HTMLCaptureTile] {
        let scale = Double(pixelHeight) / heightCSS
        let step = max(1, floor(Double(max(1, maximumPixelHeight)) / scale))
        var tiles: [HTMLCaptureTile] = []
        var top = 0.0
        while top < heightCSS {
            let bottom = min(heightCSS, top + step)
            let pixelTop = min(pixelHeight, Int((top * scale).rounded()))
            let pixelBottom = bottom >= heightCSS ? pixelHeight : min(pixelHeight, Int((bottom * scale).rounded()))
            if pixelBottom > pixelTop {
                tiles.append(HTMLCaptureTile(minYCSS: top, heightCSS: bottom - top, pixelMinY: pixelTop, pixelHeight: pixelBottom - pixelTop))
            }
            top = bottom
        }
        return tiles
    }
}

/// One horizontal slice of a capture: a rect in the web view and its place in the PNG.
nonisolated struct HTMLCaptureTile: Sendable, Equatable {
    let minYCSS: Double
    let heightCSS: Double
    let pixelMinY: Int
    let pixelHeight: Int
}
