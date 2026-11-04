import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import DrawspeakCore

nonisolated enum FeedbackImageWorker {
    @concurrent static func thumbnail(snapshot: Snapshot, blobs: BlobStore, side: CGFloat) async throws -> CGImage {
        try Task.checkCancellation()
        guard let ref = snapshot.image else { throw FeedbackLimitError.missingImage(snapshot.id) }
        let bytes = try blobs.data(for: ref)
        guard let source = CGImageSourceCreateWithData(bytes as CFData, nil) else { throw FeedbackLimitError.missingImage(snapshot.id) }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: Int(side),
            kCGImageSourceShouldCacheImmediately: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw FeedbackLimitError.missingImage(snapshot.id)
        }
        return image
    }
    @concurrent static func encode(_ image: CGImage) async throws -> Data {
        try Task.checkCancellation()
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw FeedbackLimitError.renderingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw FeedbackLimitError.renderingFailed }
        return data as Data
    }
    @concurrent static func decode(_ data: Data) async throws -> CGImage {
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else {
            throw FeedbackLimitError.renderingFailed
        }
        return image
    }
    @concurrent static func read(_ ref: BlobRef, blobs: BlobStore) async throws -> Data {
        try Task.checkCancellation()
        return try blobs.data(for: ref)
    }
}
