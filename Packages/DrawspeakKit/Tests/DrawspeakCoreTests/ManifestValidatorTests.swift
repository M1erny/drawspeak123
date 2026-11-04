import CryptoKit
import DrawspeakCore
import Foundation
import Testing

@Suite("ManifestValidator")
struct ManifestValidatorTests {
    private let baseBytes = Data("baseline-image".utf8)
    private let iterBytes = Data("iteration-image".utf8)

    private func sha(_ data: Data) -> String { BlobStore.sha256Hex(data) }

    private func entry(
        id: String, role: String = "baseline", proposalId: String? = nil, iteration: Int = 0,
        parent: String? = nil, path: String, sha256: String
    ) -> [String: Any] {
        var dict: [String: Any] = [
            "snapshotId": id, "screenId": "screen-1", "role": role, "iteration": iteration,
            "imagePath": path, "sha256": sha256, "widthPx": 390, "heightPx": 844,
            "viewport": ["width": 390, "height": 844, "deviceScaleFactor": 2],
        ]
        if let proposalId { dict["proposalId"] = proposalId }
        if let parent { dict["parentSnapshotId"] = parent }
        return dict
    }

    private func manifest(_ entries: [[String: Any]], threadId: String? = nil) throws -> ReviewManifest {
        var dict: [String: Any] = ["schemaVersion": 1, "reviewId": "rev-1", "status": "ready_for_review", "snapshots": entries]
        if let threadId { dict["threadId"] = threadId }
        return try ReviewManifest.decode(JSONSerialization.data(withJSONObject: dict))
    }

    private func canvas(threadId: String = "thread-1") -> ReviewCanvas {
        ReviewCanvas(projectId: UUID(), title: "C", thread: testThread, createdAt: fixedDate, updatedAt: fixedDate)
    }

    private var files: [String: Data] { ["base.png": baseBytes, "iter1.png": iterBytes] }

    private func validBaseline() -> [String: Any] { entry(id: "base", path: "base.png", sha256: sha(baseBytes)) }
    private func validIteration() -> [String: Any] {
        entry(id: "iter1", role: "proposal", proposalId: "a", iteration: 1, parent: "base", path: "iter1.png", sha256: sha(iterBytes))
    }

    @Test func validBaselineAndProposalAreAccepted() throws {
        let m = try manifest([validBaseline(), validIteration()], threadId: "thread-1")
        let result = ManifestValidator.validate(m, files: files, canvas: canvas())
        #expect(result.issues.isEmpty)
        #expect(result.valid.map(\.snapshotId) == ["base", "iter1"])
    }

    @Test func wrongChecksumIsRejected() throws {
        let bad = entry(id: "base", path: "base.png", sha256: sha(Data("other".utf8)))
        let result = ManifestValidator.validate(try manifest([bad]), files: files, canvas: canvas())
        #expect(result.valid.isEmpty)
        #expect(result.issues.contains { $0.snapshotId == "base" })
    }

    @Test func traversalPathIsRejected() throws {
        let bad = entry(id: "base", path: "../x.png", sha256: sha(baseBytes))
        var f = files
        f["../x.png"] = baseBytes
        f["x.png"] = baseBytes
        let result = ManifestValidator.validate(try manifest([bad]), files: f, canvas: canvas())
        #expect(result.valid.isEmpty)
        #expect(result.issues.contains { $0.snapshotId == "base" })
        #expect(!ManifestValidator.isSafeRelativePath("../x.png"))
        #expect(!ManifestValidator.isSafeRelativePath("/abs/x.png"))
        #expect(ManifestValidator.isSafeRelativePath("shots/x.png"))
    }

    @Test func duplicateSnapshotIdIsRejected() throws {
        let m = try manifest([validBaseline(), validBaseline()])
        let result = ManifestValidator.validate(m, files: files, canvas: canvas())
        #expect(result.valid.count == 1)
        #expect(result.issues.count == 1)
        #expect(result.issues.first?.snapshotId == "base")
    }

    @Test func proposalWithIterationZeroIsRejected() throws {
        let bad = entry(id: "iter0", role: "proposal", proposalId: "a", iteration: 0, path: "iter1.png", sha256: sha(iterBytes))
        let result = ManifestValidator.validate(try manifest([bad]), files: files, canvas: canvas())
        #expect(result.valid.isEmpty)
        #expect(result.issues.contains { $0.snapshotId == "iter0" })
    }

    @Test func manifestForAnotherThreadIsRejected() throws {
        let m = try manifest([validBaseline()], threadId: "thread-OTHER")
        let result = ManifestValidator.validate(m, files: files, canvas: canvas())
        #expect(result.valid.isEmpty)
        #expect(!result.issues.isEmpty)
    }
}
