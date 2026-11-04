import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Continuous numbers and sent-note visibility")
struct NumberingAndVisibilityTests {
    @Test func displayNumbersAreContinuousAfterDeletions() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let ids = (1...9).map { addTextNote(ws, snapshotId: "s1", text: "Comment \($0)") }
        for (index, id) in ids.enumerated() where ![0, 2, 8].contains(index) { ws.deleteNote(id) }
        #expect(ws.visibleNotes().map(\.ordinal) == [1, 3, 9])
        #expect(ws.displayNumber(for: ids[0]) == 1)
        #expect(ws.displayNumber(for: ids[2]) == 2)
        #expect(ws.displayNumber(for: ids[8]) == 3)
        #expect(ws.displayNumber(for: ids[1]) == nil)
    }

    @Test func sentNotesAreHiddenUntilEditedOrShown() async throws {
        let ws = makeWorkspace()
        ws.threads = FakeThreadService()
        try addImage(ws, id: "s1")
        let first = addTextNote(ws, snapshotId: "s1", text: "first")
        let second = addTextNote(ws, snapshotId: "s1", text: "second")
        _ = await sendNotes(ws, noteIds: [first])

        #expect(ws.visibleNotes().map(\.id) == [second])
        #expect(ws.displayNumber(for: second) == 1)
        #expect(ws.displayNumber(for: first) == nil)

        ws.showsSentNotes = true
        #expect(ws.visibleNotes().map(\.id) == [first, second])
        #expect(ws.displayNumber(for: second) == 2)
        ws.showsSentNotes = false

        // Editing a sent note is a new revision: it shows again.
        ws.updateNoteText(first, text: "first, changed")
        #expect(ws.visibleNotes().map(\.id) == [first, second])
    }

    @Test func showsSentNotesIsPersistedInUserDefaults() throws {
        let defaults = makeTestDefaults()
        let root = makeTempRoot()
        let locations = StorageLocations(root: root)
        func open() -> Workspace {
            Workspace(document: LibraryDocument(), blobs: BlobStore(root: locations.blobs), store: LibraryStore(fileURL: locations.libraryFile), defaults: defaults)
        }
        let ws = open()
        #expect(ws.showsSentNotes == false)
        ws.showsSentNotes = true
        #expect(defaults.bool(forKey: "drawspeak.showsSentNotes"))
        #expect(open().showsSentNotes)
    }

    @Test func packageAndManifestUseTheShownNumbersAndKeepNoteIds() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let ids = (1...9).map { addTextNote(ws, snapshotId: "s1", text: "Comment \($0)") }
        for (index, id) in ids.enumerated() where ![0, 2, 8].contains(index) { ws.deleteNote(id) }
        let canvas = try #require(ws.currentCanvas)
        let package = FeedbackPackageBuilder.build(
            canvas: canvas, noteIds: [ids[2], ids[8]], thread: testThread, batchId: "ds-num", now: fixedDate,
            displayNumbers: ws.displayNumbers()
        )
        #expect(package.items.map(\.displayNumber) == [2, 3])
        #expect(package.items.map(\.ordinal) == [3, 9])
        #expect(package.items.map(\.noteId) == [ids[2], ids[8]])
        let text = FeedbackPackageBuilder.messageText(for: package)
        #expect(text.contains("\n2. [Region] Comment 3"))
        #expect(text.contains("\n3. [Region] Comment 9"))
        #expect(!text.contains("9. [Region]"))
        let manifest = FeedbackManifest(package: package)
        let items = manifest.snapshots.flatMap(\.notes)
        #expect(items.map(\.number) == [2, 3])
        #expect(items.map(\.noteId) == [ids[2].uuidString, ids[8].uuidString])

        // Without explicit numbers the builder counts unsent notes plus the chosen ones.
        let computed = FeedbackPackageBuilder.build(canvas: canvas, noteIds: [ids[8]], thread: testThread, batchId: "ds-num2", now: fixedDate)
        #expect(computed.items.map(\.number) == [3])
    }

    @Test func draftsFreezeTheShownNumber() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let a = addTextNote(ws, snapshotId: "s1", text: "a")
        let b = addTextNote(ws, snapshotId: "s1", text: "b")
        ws.deleteNote(a)
        let draft = try #require(ws.saveDraft(noteIds: [b], canvasId: ws.currentCanvasId!))
        #expect(draft.items.map(\.number) == [1])
        #expect(draft.items.map(\.ordinal) == [2])
    }

    @Test func storedBatchItemsAndNotesWithoutNewFieldsStillDecode() throws {
        let item = BatchItem(note: Note(ordinal: 4, snapshotId: "s1", shape: regionShape, text: "x", createdAt: fixedDate, updatedAt: fixedDate))
        var itemJSON = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        itemJSON["displayNumber"] = nil
        let decodedItem = try JSONDecoder().decode(BatchItem.self, from: JSONSerialization.data(withJSONObject: itemJSON))
        #expect(decodedItem.displayNumber == nil)
        #expect(decodedItem.number == 4)

        let note = Note(ordinal: 1, snapshotId: "s1", shape: regionShape, text: "x", createdAt: fixedDate, updatedAt: fixedDate)
        var noteJSON = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(note)) as? [String: Any])
        noteJSON["refinement"] = nil
        let decodedNote = try JSONDecoder().decode(Note.self, from: JSONSerialization.data(withJSONObject: noteJSON))
        #expect(decodedNote.refinement == nil)
        #expect(decodedNote.text == "x")
    }
}
