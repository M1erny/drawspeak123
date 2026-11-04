import CoreGraphics
import Foundation

/// An immutable decoded bitmap. `CGImage` is thread-safe once created.
nonisolated final class DecodedImage: @unchecked Sendable {
    let cgImage: CGImage

    init(cgImage: CGImage) {
        self.cgImage = cgImage
    }
}
