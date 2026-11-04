import Foundation

/// Incoming review manifest v1 produced by the ui-review-variants skill.
public struct ReviewManifest: Codable, Hashable, Sendable {
    public struct Entry: Codable, Hashable, Sendable {
        public var snapshotId: String
        public var screenId: String
        public var screenTitle: String?
        public var role: SnapshotRole
        public var proposalId: String?
        public var iteration: Int
        public var parentSnapshotId: String?
        public var artifactKind: ArtifactKind?
        /// Capture image. Optional for HTML entries returned as text: the app renders its own capture.
        public var imagePath: String?
        public var sha256: String?
        public var widthPx: Int
        public var heightPx: Int
        public var viewport: Viewport
        public var capturedAt: Date?
        public var prototypePath: String?
        public var htmlPath: String?
        public var htmlSha256: String?
        public var renderPolicy: RenderPolicy?
        public var stateId: String?
        public var changeSummary: String?
        public var addressedNoteIds: [String]?
    }

    public struct Check: Codable, Hashable, Sendable {
        public var name: String
        public var result: String
        public var details: String?
    }

    public var schemaVersion: Int
    public var reviewId: String
    public var threadId: String?
    public var runId: String?
    public var status: String
    public var snapshots: [Entry]
    public var checks: [Check]?

    public static func decode(_ data: Data) throws -> ReviewManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ReviewManifest.self, from: data)
    }
}

public struct ManifestIssue: Hashable, Sendable {
    public var snapshotId: String?
    public var message: String
}

/// Validates a manifest against its bundle files and the canvas it imports into.
public enum ManifestValidator {
    public static let allowedStatus: Set<String> = ["ready_for_review", "partial", "failed"]

    /// Rejects absolute paths, traversal and empty components.
    public static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return parts.allSatisfy { !$0.isEmpty && $0 != ".." && $0 != "." }
    }

    /// - Parameters:
    ///   - files: bundle files by relative path (or by bare file name for attachments).
    ///   - canvas: target canvas; existing snapshot ids must not be replaced.
    /// - Returns: valid entries and per-entry issues. Invalid entries are quarantined, not imported.
    public static func validate(
        _ manifest: ReviewManifest,
        files: [String: Data],
        canvas: ReviewCanvas
    ) -> (valid: [ReviewManifest.Entry], issues: [ManifestIssue]) {
        var issues: [ManifestIssue] = []
        if manifest.schemaVersion != 1 {
            return ([], [ManifestIssue(snapshotId: nil, message: "Unsupported manifest schema \(manifest.schemaVersion)")])
        }
        if !allowedStatus.contains(manifest.status) {
            issues.append(ManifestIssue(snapshotId: nil, message: "Unknown status \(manifest.status)"))
        }
        if let threadId = manifest.threadId, let bound = canvas.thread?.threadId, threadId != bound {
            return ([], [ManifestIssue(snapshotId: nil, message: "Manifest belongs to another thread")])
        }
        var seen = Set<String>()
        let manifestIds = Set(manifest.snapshots.map(\.snapshotId))
        var valid: [ReviewManifest.Entry] = []
        for entry in manifest.snapshots {
            func fail(_ message: String) { issues.append(ManifestIssue(snapshotId: entry.snapshotId, message: message)) }
            guard seen.insert(entry.snapshotId).inserted else { fail("Duplicate snapshot id"); continue }
            if let existing = canvas.snapshots.first(where: { $0.id == entry.snapshotId }) {
                let sameBytes = existing.sourceBlob?.sha256 == (entry.htmlSha256 ?? entry.sha256)?.lowercased()
                if !sameBytes { fail("Snapshot id already exists with other bytes") }
                continue
            }
            guard entry.widthPx > 0, entry.heightPx > 0 else { fail("Invalid dimensions"); continue }
            switch entry.role {
            case .baseline:
                guard entry.proposalId == nil, entry.iteration == 0 else { fail("Baseline must have no proposal and iteration 0"); continue }
            case .proposal:
                guard let proposalId = entry.proposalId, !proposalId.isEmpty, entry.iteration >= 1 else {
                    fail("Proposal needs proposalId and iteration ≥ 1"); continue
                }
            }
            if let parent = entry.parentSnapshotId {
                let parentEntry = manifest.snapshots.first { $0.snapshotId == parent }
                let parentStored = canvas.snapshots.first { $0.id == parent }
                guard manifestIds.contains(parent) || parentStored != nil else { fail("Parent snapshot not found"); continue }
                let parentProposal = parentEntry?.proposalId ?? parentStored?.proposalId
                let parentScreen = parentEntry?.screenId ?? parentStored?.screenId
                if entry.role == .proposal, parentProposal != nil, parentProposal != entry.proposalId || parentScreen != entry.screenId {
                    fail("Parent belongs to another proposal or screen"); continue
                }
            }
            var hasArtifact = false
            if let imagePath = entry.imagePath {
                guard isSafeRelativePath(imagePath), let image = file(imagePath, in: files) else {
                    fail("Image file missing or path unsafe"); continue
                }
                guard let expected = entry.sha256, BlobStore.sha256Hex(image) == expected.lowercased() else { fail("Image checksum mismatch"); continue }
                hasArtifact = true
            }
            if entry.artifactKind == .html {
                guard let htmlPath = entry.htmlPath ?? entry.prototypePath, isSafeRelativePath(htmlPath), let html = file(htmlPath, in: files) else {
                    fail("HTML file missing or path unsafe"); continue
                }
                guard let expected = entry.htmlSha256, BlobStore.sha256Hex(html) == expected.lowercased() else {
                    fail("HTML checksum mismatch"); continue
                }
                hasArtifact = true
            }
            guard hasArtifact else { fail("Entry has no image or HTML"); continue }
            valid.append(entry)
        }
        return (valid, issues)
    }

    /// Looks up a bundle file by full relative path, then by its last component.
    public static func file(_ path: String, in files: [String: Data]) -> Data? {
        if let data = files[path] { return data }
        let name = (path as NSString).lastPathComponent
        return files[name]
    }
}
