import DrawspeakCore
import Foundation
import Testing

@Suite("Persistence")
struct PersistenceTests {
    @Test func libraryStoreRoundTripsNoteDraftAndOutboxEntry() async throws {
        let project = Project(name: "P", createdAt: fixedDate)
        let snapshot = Snapshot(
            id: "s1", screenId: "screen-1", role: .baseline, proposalId: nil, iteration: 0, parentSnapshotId: nil,
            kind: .image, image: BlobRef(sha256: "abc", byteCount: 3, contentType: "image/png"), html: nil,
            renderPolicy: nil, stateId: nil, widthPx: 100, heightPx: 200, viewport: Viewport(width: 100, height: 200),
            capturedAt: fixedDate, changeSummary: nil, addressedNoteIds: [], origin: .manualImport(fileName: "a.png"), title: "a.png"
        )
        let recording = Recording(
            startedAt: fixedDate, duration: 2.5, audio: BlobRef(sha256: "def", byteCount: 9, contentType: "audio/m4a"),
            state: .failed(code: "network", mayHaveBeenProcessed: true), transcript: makeTranscript("hello")
        )
        let note = Note(
            ordinal: 1, snapshotId: "s1", shape: .lasso([NPoint(x: 0.1, y: 0.1), NPoint(x: 0.5, y: 0.2), NPoint(x: 0.3, y: 0.7)]),
            text: "text", textSource: .typed, revision: 3, lastSentRevision: 2, recordings: [recording],
            createdAt: fixedDate, updatedAt: fixedDate
        )
        let item = BatchItem(note: note)
        let draft = SavedDraft(createdAt: fixedDate, thread: testThread, items: [item])
        let entry = OutboxEntry(
            id: "ds-1", createdAt: fixedDate, thread: testThread, items: [item], isRepeat: true, state: .uploading(done: 1, total: 2),
            receipt: DeliveryReceipt(threadId: "thread-1", messageId: "m", acknowledgedAt: fixedDate, attachmentCount: 2, confirmation: .reconciledFromThread),
            attempts: [DeliveryAttempt(startedAt: fixedDate, endedAt: nil, outcome: "started")], agentStatus: "running"
        )
        let canvas = ReviewCanvas(
            projectId: project.id, title: "C", thread: testThread, snapshots: [snapshot], notes: [note], nextOrdinal: 2,
            drafts: [draft], outbox: [entry], pulledMessageIds: ["m1"], createdAt: fixedDate, updatedAt: fixedDate
        )
        let document = LibraryDocument(projects: [project], canvases: [canvas], lastCanvasId: canvas.id)

        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "library.json")
        let store = LibraryStore(fileURL: url)
        #expect(try await store.load() == nil)
        try await store.save(document)
        let loaded = try await store.load()

        #expect(loaded == document)
    }

    @Test func blobStoreIsContentAddressedAndDetectsExistence() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = BlobStore(root: root)
        let a = try store.put(Data("same".utf8), contentType: "text/plain")
        let b = try store.put(Data("same".utf8), contentType: "text/plain")
        #expect(a == b)
        #expect(store.exists(a))
        #expect(try store.data(for: a) == Data("same".utf8))
        try FileManager.default.removeItem(at: store.url(for: a))
        #expect(!store.exists(a))
    }
}
