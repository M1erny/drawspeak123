import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Send to a new thread")
struct NewThreadDeliveryTests {
    @Test func successBindsCanvasAndMarksSent() async throws {
        let ws = makeWorkspace(thread: nil)
        let service = FakeThreadService()
        ws.threads = service
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "start here")

        let entry = try #require(await sendNotesToNewThread(ws, noteIds: [id], batchId: "ds-new-ok", title: " Review "))

        #expect(entry.state == .sent)
        #expect(entry.newThread == nil)
        #expect(entry.thread.threadId == "new-thread-1")
        #expect(entry.receipt?.threadId == "new-thread-1")
        #expect(entry.receipt?.messageId == "msg-new")
        #expect(entry.receipt?.confirmation == .response)
        let bound = try #require(ws.currentCanvas?.thread)
        #expect(bound.threadId == "new-thread-1")
        #expect(bound.hostURL == service.hostURL)
        #expect(bound.projectId == "proj-1")
        #expect(bound.projectTitle == "Shop")
        #expect(service.log.calls == ["launch:proj-1:Review:ds-new-ok"])
        let note = try #require(ws.note(id))
        #expect(note.lastSentRevision == note.revision)
    }

    @Test func refusedWhenCanvasAlreadyHasThread() async throws {
        let ws = makeWorkspace()
        let service = FakeThreadService()
        ws.threads = service
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "x")

        let entry = await sendNotesToNewThread(ws, noteIds: [id])

        #expect(entry == nil)
        #expect(ws.currentCanvas?.outbox.isEmpty == true)
        #expect(service.log.calls.isEmpty)
    }

    @Test func refusedWithoutConnectionOrTitle() async throws {
        let ws = makeWorkspace(thread: nil)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "x")
        #expect(await sendNotesToNewThread(ws, noteIds: [id]) == nil)
        ws.threads = FakeThreadService()
        #expect(await sendNotesToNewThread(ws, noteIds: [id], title: "  ") == nil)
        #expect(ws.currentCanvas?.outbox.isEmpty == true)
    }

    @Test func outcomeUnknownPersistsTargetAndKeepsCanvasUnbound() async throws {
        let root = makeTempRoot()
        let ws = makeWorkspace(thread: nil, root: root)
        ws.threads = FakeThreadService(launchFailure: .outcomeUnknown)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "maybe")

        let entry = try #require(await sendNotesToNewThread(ws, noteIds: [id], batchId: "ds-new-unknown"))

        #expect(entry.state == .deliveryUnknown)
        #expect(entry.newThread == NewThreadTarget(projectId: "proj-1", projectTitle: "Shop", title: "Review", clientRequestId: "ds-new-unknown"))
        #expect(entry.thread.threadId.isEmpty)
        #expect(entry.thread.hostURL == testThread.hostURL)
        #expect(ws.currentCanvas?.thread == nil)
        #expect(ws.note(id)?.lastSentRevision == nil)
        let persisted = persistedDocument(root: root)?.canvases.flatMap(\.outbox).first { $0.id == "ds-new-unknown" }
        #expect(persisted?.newThread?.clientRequestId == "ds-new-unknown")
        #expect(persisted?.state == .deliveryUnknown)
        // An unresolved launch blocks a second new thread for the same canvas.
        #expect(ws.pendingNewThreadEntry(canvasId: ws.currentCanvasId!)?.id == "ds-new-unknown")
        #expect(await sendNotesToNewThread(ws, noteIds: [id], batchId: "ds-new-other") == nil)
    }

    @Test func checkThreadRepeatsLaunchWithSameRequestId() async throws {
        let ws = makeWorkspace(thread: nil)
        ws.threads = FakeThreadService(launchFailure: .outcomeUnknown)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "maybe")
        _ = await sendNotesToNewThread(ws, noteIds: [id], batchId: "ds-new-check")
        let canvasId = try #require(ws.currentCanvasId)

        let retry = FakeThreadService()
        ws.threads = retry
        let result = await ws.reconcile(batchId: "ds-new-check", canvasId: canvasId)

        #expect(result == .found)
        #expect(retry.log.calls == ["launch:proj-1:Review:ds-new-check"])
        let entry = try #require(ws.currentCanvas?.outbox.first)
        #expect(entry.state == .sent)
        #expect(entry.attempts.count == 2)
        #expect(ws.currentCanvas?.thread?.threadId == "new-thread-1")
        #expect(ws.note(id)?.lastSentRevision != nil)
    }

    @Test func refusedRepeatKeepsDeliveryUnknown() async throws {
        let ws = makeWorkspace(thread: nil)
        ws.threads = FakeThreadService(launchFailure: .outcomeUnknown)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "maybe")
        _ = await sendNotesToNewThread(ws, noteIds: [id], batchId: "ds-new-refused")
        let canvasId = try #require(ws.currentCanvasId)

        ws.threads = FakeThreadService(launchFailure: .notAuthorized)
        #expect(await ws.reconcile(batchId: "ds-new-refused", canvasId: canvasId) == .unavailable)
        #expect(ws.currentCanvas?.outbox.first?.state == .deliveryUnknown)
        #expect(ws.currentCanvas?.thread == nil)
    }

    @Test func checkThreadAfterBindingKeepsCanvasThread() async throws {
        let ws = makeWorkspace(thread: nil)
        ws.threads = FakeThreadService(launchFailure: .outcomeUnknown)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "maybe")
        _ = await sendNotesToNewThread(ws, noteIds: [id], batchId: "ds-new-bound")
        let canvasId = try #require(ws.currentCanvasId)
        #expect(ws.bindThread(testThread, to: canvasId))

        ws.threads = FakeThreadService()
        #expect(await ws.reconcile(batchId: "ds-new-bound", canvasId: canvasId) == .found)
        #expect(ws.currentCanvas?.thread == testThread)
        #expect(ws.currentCanvas?.outbox.first?.receipt?.threadId == "new-thread-1")
    }

    @Test func failedRetryUsesSameRequestIdButNotOnceBound() async throws {
        let ws = makeWorkspace(thread: nil)
        ws.threads = FakeThreadService(launchFailure: .notSent("offline"))
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "x")
        let entry = await sendNotesToNewThread(ws, noteIds: [id], batchId: "ds-new-failed")
        #expect(entry?.state == .failed(reason: "offline"))
        #expect(ws.pendingNewThreadEntry(canvasId: ws.currentCanvasId!) == nil)
        let canvasId = try #require(ws.currentCanvasId)

        let retry = FakeThreadService()
        ws.threads = retry
        await ws.deliver(batchId: "ds-new-failed", canvasId: canvasId)
        #expect(retry.log.calls == ["launch:proj-1:Review:ds-new-failed"])
        #expect(ws.currentCanvas?.outbox.first?.state == .sent)

        // A failed launch never adds a second thread to a bound canvas.
        let other = makeWorkspace(thread: nil)
        other.threads = FakeThreadService(launchFailure: .notSent("offline"))
        try addImage(other, id: "s1")
        let note = addTextNote(other, snapshotId: "s1", text: "x")
        _ = await sendNotesToNewThread(other, noteIds: [note], batchId: "ds-new-failed-2")
        let otherId = try #require(other.currentCanvasId)
        #expect(other.bindThread(testThread, to: otherId))
        let blocked = FakeThreadService()
        other.threads = blocked
        await other.deliver(batchId: "ds-new-failed-2", canvasId: otherId)
        #expect(blocked.log.calls.isEmpty)
        #expect(other.currentCanvas?.outbox.first?.state == .failed(reason: "This canvas already has a thread."))
    }

    @Test func outboxEntryDecodesWithoutNewThreadField() throws {
        let entry = OutboxEntry(id: "old", createdAt: fixedDate, thread: testThread, items: [], isRepeat: false, state: .sent)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any])
        #expect(object["newThread"] == nil)
        object.removeValue(forKey: "newThread")
        let decoded = try JSONDecoder().decode(OutboxEntry.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded == entry)
        #expect(decoded.newThread == nil)
    }
}
