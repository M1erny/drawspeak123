import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Delivery and recovery (AC-11, AC-12)")
struct DeliveryTests {
    @Test func successMarksSentWithReceiptAndNoteRevisions() async throws {
        let ws = makeWorkspace()
        ws.threads = FakeThreadService()
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "ship it")

        let result = await sendNotes(ws, noteIds: [id])

        let entry = try #require(result.entry)
        #expect(entry.state == .sent)
        let receipt = try #require(entry.receipt)
        #expect(receipt.confirmation == .response)
        #expect(receipt.messageId == "msg-1")
        #expect(receipt.threadId == "thread-1")
        let note = try #require(ws.note(id))
        #expect(note.lastSentRevision == note.revision)
    }

    @Test func outcomeUnknownLeavesDeliveryUnknownAndNotesUnsent() async throws {
        let ws = makeWorkspace()
        ws.threads = FakeThreadService(sendFailure: .outcomeUnknown)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "maybe delivered")

        let result = await sendNotes(ws, noteIds: [id])

        #expect(result.entry?.state == .deliveryUnknown)
        #expect(result.entry?.receipt == nil)
        #expect(ws.note(id)?.lastSentRevision == nil)
    }

    @Test func notSentFailureIsFailedAndNotesUnsent() async throws {
        let ws = makeWorkspace()
        ws.threads = FakeThreadService(sendFailure: .notSent("offline"))
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "x")

        let result = await sendNotes(ws, noteIds: [id])

        #expect(result.entry?.state == .failed(reason: "offline"))
        #expect(ws.note(id)?.lastSentRevision == nil)
    }

    @Test func recoveryMapsSendingToUnknownAndUploadingToReady() {
        func entry(_ state: DeliveryState) -> OutboxEntry {
            OutboxEntry(id: "b", createdAt: fixedDate, thread: testThread, items: [], isRepeat: false, state: state)
        }
        #expect(OutboxRecovery.recover(entry(.sending)).state == .deliveryUnknown)
        #expect(OutboxRecovery.recover(entry(.uploading(done: 1, total: 3))).state == .readyToSend)
        #expect(OutboxRecovery.recover(entry(.sent)).state == .sent)
        #expect(OutboxRecovery.recover(entry(.deliveryUnknown)).state == .deliveryUnknown)
        #expect(OutboxRecovery.recover(entry(.readyToSend)).state == .readyToSend)
    }

    @Test func workspaceInitRecoversPersistedOutboxEntries() throws {
        let sending = OutboxEntry(id: "b1", createdAt: fixedDate, thread: testThread, items: [], isRepeat: false, state: .sending)
        let uploading = OutboxEntry(id: "b2", createdAt: fixedDate, thread: testThread, items: [], isRepeat: false, state: .uploading(done: 0, total: 2))
        let project = Project(name: "P", createdAt: fixedDate)
        let canvas = ReviewCanvas(projectId: project.id, title: "C", thread: testThread, outbox: [sending, uploading], createdAt: fixedDate, updatedAt: fixedDate)
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let ws = Workspace(
            document: LibraryDocument(projects: [project], canvases: [canvas], lastCanvasId: canvas.id),
            blobs: BlobStore(root: root.appending(path: "blobs")),
            store: LibraryStore(fileURL: root.appending(path: "library.json"))
        )
        let states = Dictionary(uniqueKeysWithValues: (ws.currentCanvas?.outbox ?? []).map { ($0.id, $0.state) })
        #expect(states["b1"] == .deliveryUnknown)
        #expect(states["b2"] == .readyToSend)
    }

    @Test func reconcileFindsMarkerAndMarksSentFromThread() async throws {
        let ws = makeWorkspace()
        ws.threads = FakeThreadService(sendFailure: .outcomeUnknown)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "unknown outcome")
        let result = await sendNotes(ws, noteIds: [id], batchId: "ds-recon-1")
        #expect(result.entry?.state == .deliveryUnknown)
        let canvasId = try #require(ws.currentCanvasId)

        let message = ThreadMessage(
            id: "m-99", role: "user", text: "Drawspeak feedback ... Batch: \(result.package.marker)",
            createdAt: fixedDate, attachments: []
        )
        ws.threads = FakeThreadService(messages: [message])
        let reconciled = await ws.reconcile(batchId: "ds-recon-1", canvasId: canvasId)

        #expect(reconciled == .found)
        let entry = try #require(ws.currentCanvas?.outbox.first)
        #expect(entry.state == .sent)
        #expect(entry.receipt?.confirmation == .reconciledFromThread)
        #expect(entry.receipt?.messageId == "m-99")
        let note = try #require(ws.note(id))
        #expect(note.lastSentRevision == note.revision)
    }

    @Test func reconcileWithoutMarkerReturnsToReadyToSend() async throws {
        let ws = makeWorkspace()
        ws.threads = FakeThreadService(sendFailure: .outcomeUnknown)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "unknown outcome")
        _ = await sendNotes(ws, noteIds: [id], batchId: "ds-recon-2")
        let canvasId = try #require(ws.currentCanvasId)

        let other = ThreadMessage(id: "m-1", role: "user", text: "unrelated drawspeak-batch:ds-other", createdAt: nil, attachments: [])
        ws.threads = FakeThreadService(messages: [other])
        let reconciled = await ws.reconcile(batchId: "ds-recon-2", canvasId: canvasId)

        #expect(reconciled == .notFound)
        #expect(ws.currentCanvas?.outbox.first?.state == .readyToSend)
        #expect(ws.note(id)?.lastSentRevision == nil)
    }
}
