import DrawspeakCore
import FeedbackKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Renders the marked area of a note (with its mark and some context) as a PNG
/// for the transcript refiner.
enum RegionCropper {
    /// Fraction of the mark's size added around it, so the model sees context.
    static let contextMargin = 0.6
    static let minimumSide = 0.25

    static func png(for note: Note, snapshot: Snapshot, blobs: BlobStore) async -> Data? {
        guard let composite = try? await CompositeRenderer.render(
            snapshot: snapshot, items: [BatchItem(note: note)], blobs: blobs, maxLongSide: 1600
        ) else { return nil }
        return crop(composite, to: cropRect(for: note.shape.bounds))
    }

    /// The normalized crop: the mark grown by the margin, at least `minimumSide` wide and tall.
    static func cropRect(for bounds: NRect) -> NRect {
        let width = max(bounds.width * (1 + contextMargin * 2), minimumSide)
        let height = max(bounds.height * (1 + contextMargin * 2), minimumSide)
        return NRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height).clamped()
    }

    private static func crop(_ png: Data, to rect: NRect) -> Data? {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let pixels = CGRect(
            x: rect.x * Double(image.width), y: rect.y * Double(image.height),
            width: rect.width * Double(image.width), height: rect.height * Double(image.height)
        ).integral
        guard let cropped = image.cropping(to: pixels) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cropped, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
