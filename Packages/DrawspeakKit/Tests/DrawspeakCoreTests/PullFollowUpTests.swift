import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Pulled follow-ups: additive or swap")
struct PullFollowUpTests {
    private func entry(id: String, iteration: Int, parent: String?) -> [String: Any] {
        var row: [String: Any] = [
            "snapshotId": id, "screenId": "checkout", "screenTitle": "Checkout", "role": "proposal", "proposalId": "a",
            "iteration": iteration, "imagePath": "\(id).png", "sha256": BlobStore.sha256Hex(Data(id.utf8)),
            "widthPx": 100, "heightPx": 200, "viewport": ["width": 100, "height": 200, "deviceScaleFactor": 1],
        ]
        if let parent { row["parentSnapshotId"] = parent }
        return row
    }

    private func reply(id: String, entries: [[String: Any]]) throws -> ThreadMessage {
        let manifest: [String: Any] = ["schemaVersion": 1, "reviewId": "rev-\(id)", "status": "ready_for_review", "threadId": "thread-1", "snapshots": entries]
        let json = try #require(String(data: try JSONSerialization.data(withJSONObject: manifest), encoding: .utf8))
        var text = "Here you go.\n````drawspeak-manifest\n\(json)\n````\n"
        for row in entries {
            let snapshotId = try #require(row["snapshotId"] as? String)
            text += "````drawspeak-file path=\"\(snapshotId).png\"\n\(snapshotId)\n````\n"
        }
        return ThreadMessage(id: id, role: "assistant", text: text, createdAt: fixedDate, attachments: [])
    }

    private let noCapture: Workspace.HTMLCapturer = { _, _, _ in throw CancellationError() }

    /// Pulls iteration 1, then a reply with iteration 2 of the same proposal.
    private func pullTwoIterations(additive: Bool) async throws -> ReviewCanvas {
        let ws = makeWorkspace()
        ws.pullFollowUpsAdditive = { additive }
        let canvasId = try #require(ws.currentCanvasId)
        let first = try reply(id: "m1", entries: [entry(id: "a-1", iteration: 1, parent: nil)])
        ws.threads = FakeThreadService(messages: [first])
        _ = await ws.pull(canvasId: canvasId, captureHTML: noCapture)
        let second = try reply(id: "m2", entries: [entry(id: "a-2", iteration: 2, parent: "a-1")])
        ws.threads = FakeThreadService(messages: [first, second])
        let report = await ws.pull(canvasId: canvasId, captureHTML: noCapture)
        #expect(report.importedSnapshots == 1, "\(report.issues)")
        return try #require(ws.currentCanvas)
    }

    @Test func additiveKeepsTheEarlierIterationAndAddsItsOwnColumn() async throws {
        let canvas = try await pullTwoIterations(additive: true)
        let screen = try #require(canvas.screens.first { $0.id == "checkout" })
        let lanes = CanvasLayout.lanes(in: canvas, screen: screen)
        #expect(lanes.map(\.title) == ["Proposal A", "Proposal A · 2"])
        #expect(lanes.map { $0.selected?.id } == ["a-1", "a-2"])
        // The thread's identity is untouched: both are proposal a, iterations 1 and 2.
        let follow = try #require(canvas.snapshots.first { $0.id == "a-2" })
        #expect(follow.proposalId == "a" && follow.iteration == 2 && follow.parentSnapshotId == "a-1")
        #expect(follow.laneId == "a-2")
    }

    @Test func swapShowsTheNewIterationInTheSameColumn() async throws {
        let canvas = try await pullTwoIterations(additive: false)
        let screen = try #require(canvas.screens.first { $0.id == "checkout" })
        let lanes = CanvasLayout.lanes(in: canvas, screen: screen)
        #expect(lanes.map(\.title) == ["Proposal A"])
        #expect(lanes.first?.versions.map(\.id) == ["a-1", "a-2"])
        #expect(lanes.first?.selected?.id == "a-2")
    }

    @Test func followUpLaneIdsRoundTrip() {
        #expect(CanvasLayout.followUpLaneId(proposalId: "a", iteration: 3) == "a-3")
        #expect(CanvasLayout.baseProposalId("a-3") == "a")
        #expect(CanvasLayout.baseProposalId("a") == "a")
        #expect(CanvasLayout.baseProposalId("option-b") == "option-b")
        #expect(CanvasLayout.proposalTitle("a-3") == "Proposal A · 3")
    }
}
