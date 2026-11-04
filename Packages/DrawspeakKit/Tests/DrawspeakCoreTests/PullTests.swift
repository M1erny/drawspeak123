import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Pull (F10, UX F03) and capture repair (F11)")
struct PullTests {
    private func imageEntry(id: String, screenId: String, body: String) -> [String: Any] {
        [
            "snapshotId": id, "screenId": screenId, "role": "baseline", "iteration": 0,
            "imagePath": "\(id).png", "sha256": BlobStore.sha256Hex(Data(body.utf8)), "widthPx": 100, "heightPx": 200,
            "viewport": ["width": 100, "height": 200, "deviceScaleFactor": 1],
        ]
    }

    private func reply(id: String, entries: [[String: Any]], files: [String: String]) throws -> ThreadMessage {
        let manifest: [String: Any] = ["schemaVersion": 1, "reviewId": "rev-\(id)", "status": "ready_for_review", "threadId": "thread-1", "snapshots": entries]
        let json = try #require(String(data: try JSONSerialization.data(withJSONObject: manifest), encoding: .utf8))
        var text = "Here you go.\n````drawspeak-manifest\n\(json)\n````\n"
        for (path, body) in files.sorted(by: { $0.key < $1.key }) {
            text += "````drawspeak-file path=\"\(path)\"\n\(body)\n````\n"
        }
        return ThreadMessage(id: id, role: "assistant", text: text, createdAt: fixedDate, attachments: [])
    }

    private let noCapture: Workspace.HTMLCapturer = { _, _, _ in throw CancellationError() }

    @Test func failedEntryStaysRetryableAndSucceedsOnTheNextPull() async throws {
        let ws = makeWorkspace()
        let canvasId = try #require(ws.currentCanvasId)
        let message = try reply(id: "m1", entries: [imageEntry(id: "new-1", screenId: "screen-x", body: "pulled-bytes")], files: ["new-1.png": "pulled-bytes"])
        ws.threads = FakeThreadService(messages: [message])
        try FileManager.default.createDirectory(at: ws.blobs.root, withIntermediateDirectories: true)

        try setWritable(ws.blobs.root, false)
        let first = await ws.pull(canvasId: canvasId, captureHTML: noCapture)
        try setWritable(ws.blobs.root, true)
        #expect(first.importedSnapshots == 0)
        #expect(ws.currentCanvas?.pulledMessageIds.isEmpty == true)

        let second = await ws.pull(canvasId: canvasId, captureHTML: noCapture)
        #expect(second.importedSnapshots == 1)
        #expect(ws.currentCanvas?.pulledMessageIds == ["m1"])
        #expect(ws.currentCanvas?.snapshots.contains { $0.id == "new-1" } == true)

        let third = await ws.pull(canvasId: canvasId, captureHTML: noCapture)
        #expect(third.importedSnapshots == 0)
    }

    @Test func pulledBaselineForAScreenWithNowDoesNotChangeNow() async throws {
        let ws = makeWorkspace()
        let original = try addImage(ws, id: "s1")
        let canvasId = try #require(ws.currentCanvasId)
        let revisionsBefore = try #require(ws.currentCanvas).baselineRevisions
        let message = try reply(id: "m1", entries: [imageEntry(id: "s1-ref2", screenId: original.screenId, body: "reference-2")], files: ["s1-ref2.png": "reference-2"])
        ws.threads = FakeThreadService(messages: [message])

        let report = await ws.pull(canvasId: canvasId, captureHTML: noCapture)

        #expect(report.importedSnapshots == 1)
        let canvas = try #require(ws.currentCanvas)
        let pulled = try #require(canvas.snapshots.first { $0.id == "s1-ref2" })
        #expect(canvas.baselineRevisions == revisionsBefore)
        #expect(CanvasLayout.now(in: canvas, screenId: original.screenId)?.id == "s1")
        #expect(CanvasLayout.isUnpromotedBaseline(pulled, in: canvas))
        #expect(!CanvasLayout.isUnpromotedBaseline(original, in: canvas))
        let screen = try #require(canvas.screens.first { $0.id == original.screenId })
        let nowLane = try #require(CanvasLayout.lanes(in: canvas, screen: screen).first)
        #expect(nowLane.versions.map(\.id) == ["s1", "s1-ref2"])
        #expect(nowLane.selected?.id == "s1")

        ws.promoteToNow("s1-ref2")
        let promoted = try #require(ws.currentCanvas)
        #expect(CanvasLayout.now(in: promoted, screenId: original.screenId)?.id == "s1-ref2")
        #expect(!CanvasLayout.isUnpromotedBaseline(pulled, in: promoted))
    }

    @Test func pulledBaselineForANewScreenBecomesItsFirstNow() async throws {
        let ws = makeWorkspace()
        let canvasId = try #require(ws.currentCanvasId)
        let message = try reply(id: "m1", entries: [imageEntry(id: "fresh-now", screenId: "screen-new", body: "fresh")], files: ["fresh-now.png": "fresh"])
        ws.threads = FakeThreadService(messages: [message])

        _ = await ws.pull(canvasId: canvasId, captureHTML: noCapture)

        let canvas = try #require(ws.currentCanvas)
        #expect(CanvasLayout.now(in: canvas, screenId: "screen-new")?.id == "fresh-now")
    }

    @Test func htmlWithoutCaptureIsUnavailableUntilACaptureIsAttached() throws {
        let ws = makeWorkspace()
        let canvasId = try #require(ws.currentCanvasId)
        let snapshot = try ws.importArtifact(
            into: canvasId, data: Data("<html><body>hi</body></html>".utf8), kind: .html, contentType: "text/html",
            fileName: "a.html", pixelSize: (width: 390, height: 844), viewport: .defaultHTML, target: .newScreen(title: "A")
        )
        let id = addTextNote(ws, snapshotId: snapshot.id, text: "Bigger title")
        #expect(ws.needsCapture(snapshot))

        let scope = try #require(ws.feedbackScope(canvasId: canvasId))
        #expect(scope.unavailable.first?.note.id == id)
        #expect(scope.unavailable.first?.reason == "Preview image is still being created")

        ws.attachCapture(Data("png".utf8), pixelSize: (width: 780, height: 1688), to: snapshot.id, canvasId: canvasId)
        let repaired = try #require(ws.currentCanvas?.snapshots.first { $0.id == snapshot.id })
        #expect(!ws.needsCapture(repaired))
        #expect(ws.feedbackScope(canvasId: canvasId)?.ready.map(\.id) == [id])
    }
}
