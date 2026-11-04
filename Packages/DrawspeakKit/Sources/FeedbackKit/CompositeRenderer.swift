import SwiftUI
import DrawspeakCore

public enum CompositeRenderer {
    public static func render(snapshot: Snapshot, items: [BatchItem], blobs: BlobStore, maxLongSide: CGFloat = 2400) async throws -> Data {
        guard maxLongSide.isFinite, maxLongSide > 0 else { throw FeedbackLimitError.renderingFailed }
        var side = min(maxLongSide, 2400)
        while side >= 1 {
            try Task.checkCancellation()
            let image = try await FeedbackImageWorker.thumbnail(snapshot: snapshot, blobs: blobs, side: side)
            let size = CGSize(width: image.width, height: image.height)
            let renderer = ImageRenderer(content: CompositeCanvas(image: image, items: items).frame(width: size.width, height: size.height))
            renderer.scale = 1
            guard let output = renderer.cgImage else { throw FeedbackLimitError.renderingFailed }
            let data = try await FeedbackImageWorker.encode(output)
            if data.count <= 10 * 1024 * 1024 { return data }
            side *= 0.75
        }
        throw FeedbackLimitError.renderingFailed
    }
}
