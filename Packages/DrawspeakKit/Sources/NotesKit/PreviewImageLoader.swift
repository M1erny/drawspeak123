import Foundation
import ImageIO

nonisolated enum PreviewImageLoader {
    @concurrent static func load(_ key: PreviewImageKey) async -> CGImage? {
        guard let url = key.url,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 900,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { return nil }
        let crop = key.crop
        return image.cropping(to: CGRect(x: crop.x * Double(image.width), y: crop.y * Double(image.height),
                                        width: crop.width * Double(image.width), height: crop.height * Double(image.height)))
    }
}
