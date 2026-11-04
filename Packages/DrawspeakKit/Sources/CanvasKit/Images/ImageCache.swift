import CoreGraphics
import DrawspeakCore
import Foundation
import ImageIO

/// Decodes snapshot images off the main thread, downsampled to what the card
/// needs on screen, and keeps them in a memory-pressure-aware cache.
actor ImageCache {
    static let shared = ImageCache()

    /// Decode sizes, in pixels along the longer side. Cards request the
    /// smallest bucket covering their on-screen size.
    static let buckets = [512, 1024, 2048, 4096]

    private let cache: NSCache<NSString, DecodedImage> = {
        let cache = NSCache<NSString, DecodedImage>()
        cache.totalCostLimit = 192 * 1024 * 1024
        return cache
    }()

    /// The bucket for a card whose longer side is `worldWidth` world points,
    /// at `zoom` on a `displayScale` screen.
    nonisolated static func bucket(worldWidth: Double, zoom: Double, displayScale: Double) -> Int {
        let needed = worldWidth * max(zoom, 0) * max(displayScale, 1)
        return buckets.first { Double($0) >= needed } ?? buckets[buckets.count - 1]
    }

    func image(at url: URL, maxPixelSize: Int) -> DecodedImage? {
        let key = "\(url.lastPathComponent)#\(maxPixelSize)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        let image = DecodedImage(cgImage: cgImage)
        cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}
