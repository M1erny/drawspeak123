import SwiftUI
import DrawspeakCore
import ImageIO
import UniformTypeIdentifiers

public enum CompositeRenderer {
    public static func render(snapshot: Snapshot, items: [BatchItem], blobs: BlobStore, maxLongSide: CGFloat = 2400) async throws -> Data {
        guard let ref = snapshot.image, let bytes = try? blobs.data(for: ref),
              let source = CGImageSourceCreateWithData(bytes as CFData, nil) else {
            throw FeedbackLimitError.missingImage(snapshot.id)
        }
        guard maxLongSide.isFinite, maxLongSide > 0 else { throw FeedbackLimitError.renderingFailed }
        var side = min(maxLongSide, 2400)
        while side >= 1 {
            try Task.checkCancellation()
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                          kCGImageSourceCreateThumbnailWithTransform: true,
                                          kCGImageSourceThumbnailMaxPixelSize: Int(side)]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                throw FeedbackLimitError.missingImage(snapshot.id)
            }
            let size = CGSize(width: image.width, height: image.height)
            let renderer = ImageRenderer(content: CompositeCanvas(image: image, items: items).frame(width: size.width, height: size.height))
            renderer.scale = 1
            guard let output = renderer.cgImage else { throw FeedbackLimitError.renderingFailed }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
                throw FeedbackLimitError.renderingFailed
            }
            CGImageDestinationAddImage(destination, output, nil)
            guard CGImageDestinationFinalize(destination) else { throw FeedbackLimitError.renderingFailed }
            if data.length <= 10 * 1024 * 1024 { return data as Data }
            side *= 0.75
            await Task.yield()
        }
        throw FeedbackLimitError.renderingFailed
    }
}
