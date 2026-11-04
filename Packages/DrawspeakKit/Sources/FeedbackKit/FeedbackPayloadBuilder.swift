import DrawspeakCore

public enum FeedbackPayloadBuilder {
    public static func validate(_ package: FeedbackPackage) throws {
        guard package.groups.count <= 7 else { throw FeedbackLimitError.tooManySnapshots(max: 7) }
        guard FeedbackPackageBuilder.messageText(for: package).count <= 120_000 else { throw FeedbackLimitError.textTooLong }
    }

    public static func attachments(for package: FeedbackPackage, blobs: BlobStore) async throws -> [OutgoingAttachment] {
        try validate(package)
        var result: [OutgoingAttachment] = []
        for group in package.groups {
            let png = try await CompositeRenderer.render(snapshot: group.snapshot, items: group.items, blobs: blobs)
            result.append(OutgoingAttachment(fileName: group.compositeFileName, contentType: "image/png", data: png))
        }
        result.append(OutgoingAttachment(fileName: package.manifestFileName, contentType: "application/json", data: try FeedbackManifest(package: package).jsonData()))
        return result
    }
}
