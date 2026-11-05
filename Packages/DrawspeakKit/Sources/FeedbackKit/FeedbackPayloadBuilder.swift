import Foundation
import DrawspeakCore

public enum FeedbackPayloadBuilder {
    /// Checks every message the package will be sent as. Attachment counts never block:
    /// `FeedbackPackageSplitter` sends a large review as several messages.
    public static func validate(_ package: FeedbackPackage) throws {
        for part in FeedbackPackageSplitter.split(package) {
            guard FeedbackPackageBuilder.messageText(for: part).count <= FeedbackPackageSplitter.maxMessageCharacters else {
                throw FeedbackLimitError.textTooLong
            }
        }
    }

    /// The attachments of one message. Pass a part from `FeedbackPackageSplitter.split`;
    /// a package that needs more than one message is rejected.
    public static func attachments(for package: FeedbackPackage, blobs: BlobStore, style: AnnotationStyle = .standard) async throws -> [OutgoingAttachment] {
        guard FeedbackPackageSplitter.fits(package) else { throw FeedbackLimitError.needsSplit }
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
