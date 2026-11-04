import Foundation
import DrawspeakCore

public enum FeedbackPayloadBuilder {
    public static func validate(_ package: FeedbackPackage) throws {
        let costs = package.groups.map { $0.snapshot.kind == .html ? 2 : 1 }
        let count = costs.reduce(1, +) // PNGs, exact HTML sources, and one manifest.
        if count > 8 {
            var remaining = count
            var snapshotsToRemove = 0
            for cost in costs.sorted(by: >) where remaining > 8 {
                remaining -= cost
                snapshotsToRemove += 1
            }
            throw FeedbackLimitError.tooManyAttachments(count: count, snapshotsToRemove: snapshotsToRemove)
        }
        guard FeedbackPackageBuilder.messageText(for: package).count <= 120_000 else { throw FeedbackLimitError.textTooLong }
    }

    public static func attachments(for package: FeedbackPackage, blobs: BlobStore, style: AnnotationStyle = .standard) async throws -> [OutgoingAttachment] {
        try validate(package)
        var result: [OutgoingAttachment] = []
        for group in package.groups {
            let png = try await CompositeRenderer.render(snapshot: group.snapshot, items: group.items, blobs: blobs, style: style)
            result.append(OutgoingAttachment(fileName: group.compositeFileName, contentType: "image/png", data: png))
        }
        for group in package.groups where group.snapshot.kind == .html {
            guard let source = group.snapshot.html else { throw FeedbackLimitError.missingHTML(group.snapshot.id) }
            let bytes = try await FeedbackImageWorker.read(source, blobs: blobs)
            let stem = (group.compositeFileName as NSString).deletingPathExtension
            result.append(OutgoingAttachment(fileName: "\(stem).html", contentType: "text/html", data: bytes))
        }
        result.append(OutgoingAttachment(fileName: package.manifestFileName, contentType: "application/json", data: try FeedbackManifest(package: package).jsonData()))
        return result
    }
}
