import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("FeedbackPackageBuilder")
struct FeedbackPackageBuilderTests {
    @Test func groupsNotesBySnapshotInOrdinalOrderAndWritesMarkerAndManifest() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        try addImage(ws, id: "s2")
        let a = addTextNote(ws, snapshotId: "s1", text: "alpha comment")      // ordinal 1
        let b = addTextNote(ws, snapshotId: "s2", text: "bravo comment")      // ordinal 2
        let c = addTextNote(ws, snapshotId: "s1", text: "charlie comment")    // ordinal 3

        let canvas = try #require(ws.currentCanvas)
        let package = FeedbackPackageBuilder.build(
            canvas: canvas, noteIds: [a, b, c], thread: testThread, batchId: "ds-batch-42", now: fixedDate
        )

        #expect(package.groups.count == 2)
        let first = try #require(package.groups.first)
        #expect(first.snapshot.id == "s1")
        #expect(first.items.map(\.noteId) == [a, c])
        #expect(first.items.map(\.ordinal) == [1, 3])
        #expect(package.groups[1].items.map(\.noteId) == [b])
        #expect(package.marker == "drawspeak-batch:ds-batch-42")

        let text = FeedbackPackageBuilder.messageText(for: package)
        #expect(text.contains("drawspeak-batch:ds-batch-42"))
        for note in ["alpha comment", "bravo comment", "charlie comment"] {
            #expect(text.contains(note))
        }

        let manifest = FeedbackManifest(package: package)
        let data = try manifest.jsonData()
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let snapshots = try #require(json["snapshots"] as? [[String: Any]])
        #expect(snapshots.count == 2)
        let jsonString = try #require(String(data: data, encoding: .utf8))
        for id in [a, b, c] {
            #expect(jsonString.contains(id.uuidString))
        }
        #expect(json["batchId"] as? String == "ds-batch-42")
        #expect(json["threadId"] as? String == "thread-1")
    }

    @Test func packageOnlyContainsChosenNotes() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let a = addTextNote(ws, snapshotId: "s1", text: "keep")
        _ = addTextNote(ws, snapshotId: "s1", text: "leave out")
        let package = FeedbackPackageBuilder.build(
            canvas: try #require(ws.currentCanvas), noteIds: [a], thread: testThread, batchId: "b", now: fixedDate
        )
        #expect(package.items.map(\.noteId) == [a])
        #expect(!FeedbackPackageBuilder.messageText(for: package).contains("leave out"))
    }
}
