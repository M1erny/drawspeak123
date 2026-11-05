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
        #expect(package.marker == "[drawspeak-batch:ds-batch-42]")
        #expect(FeedbackPackage.marker(batchId: "ds-batch-42") == package.marker)

        let text = FeedbackPackageBuilder.messageText(for: package)
        // The exact marker leads the first line (inside the 1000-character queue preview).
        #expect(text.components(separatedBy: "\n").first?.hasPrefix("[drawspeak-batch:ds-batch-42] ") == true)
        #expect(!text.contains("[[drawspeak-batch"))
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

    /// A canvas whose snapshot `s1` is Proposal `a`, iteration 1, with a later iteration 2 (`s2`) of the same proposal.
    private func proposalCanvas() throws -> (ReviewCanvas, UUID, UUID) {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let onProposal = addTextNote(ws, snapshotId: "s1", text: "make it bigger")
        var canvas = try #require(ws.currentCanvas)
        let index = try #require(canvas.snapshots.firstIndex { $0.id == "s1" })
        canvas.snapshots[index].role = .proposal
        canvas.snapshots[index].proposalId = "a"
        canvas.snapshots[index].iteration = 1
        var later = canvas.snapshots[index]
        later.id = "s2"; later.iteration = 2; later.parentSnapshotId = "s1"
        canvas.snapshots.append(later)
        return (canvas, onProposal, onProposal)
    }

    @Test func commentsOnAProposalDefaultToContinueWithTheNextIteration() throws {
        let (canvas, note, _) = try proposalCanvas()
        let package = FeedbackPackageBuilder.build(canvas: canvas, noteIds: [note], thread: testThread, batchId: "b", now: fixedDate)
        #expect(package.directive.mode == .continueProposals)
        let text = FeedbackPackageBuilder.messageText(for: package)
        #expect(text.contains("export iteration 3 with proposalId `a`"))
        #expect(text.contains("parentSnapshotId `s1`"))
        #expect(text.contains("--previous"))
        #expect(!text.contains("create 2 new"))
    }

    @Test func commentsOnNowDefaultToNewVariantsAndNameTheCount() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let note = addTextNote(ws, snapshotId: "s1", text: "alpha")
        let canvas = try #require(ws.currentCanvas)
        let package = FeedbackPackageBuilder.build(canvas: canvas, noteIds: [note], thread: testThread, batchId: "b", now: fixedDate)
        #expect(package.directive.mode == .newVariants)
        #expect(FeedbackPackageBuilder.messageText(for: package).contains("create 2 new alternative proposals"))

        let one = FeedbackPackageBuilder.build(canvas: canvas, noteIds: [note], thread: testThread, batchId: "b", now: fixedDate,
            directive: AgentDirective(mode: .newVariants, variantCount: 1))
        #expect(FeedbackPackageBuilder.messageText(for: one).contains("create 1 new alternative proposal that addresses these comments"))
        #expect(FeedbackPackageBuilder.messageText(for: package).contains("create 2 new alternative proposals that address these comments"))
        #expect(FeedbackPackageBuilder.messageText(for: package).contains("inside the project directory"))
    }

    @Test func newVariantsListUsedProposalIdsAndKeepExistingUntouched() throws {
        let (canvas, note, _) = try proposalCanvas()
        let package = FeedbackPackageBuilder.build(canvas: canvas, noteIds: [note], thread: testThread, batchId: "b", now: fixedDate,
            directive: AgentDirective(mode: .newVariants, variantCount: 3))
        let text = FeedbackPackageBuilder.messageText(for: package)
        #expect(text.contains("create 3 new alternative proposals"))
        #expect(text.contains("proposalIds already used: a"))
        #expect(text.contains("Leave existing proposals unchanged"))
    }

    @Test func replyOnlyForbidsBuildingAndNoteIsPassedOn() throws {
        let (canvas, note, _) = try proposalCanvas()
        let package = FeedbackPackageBuilder.build(canvas: canvas, noteIds: [note], thread: testThread, batchId: "b", now: fixedDate,
            directive: AgentDirective(mode: .replyOnly, note: "  only touch the header  "))
        let text = FeedbackPackageBuilder.messageText(for: package)
        #expect(text.contains("answer the comments in text only"))
        #expect(!text.contains("drawspeak_bundle"))
        #expect(text.contains("Additional instruction from the reviewer: only touch the header"))
    }

    @Test func variantCountIsClampedAndDirectiveSurvivesEncoding() throws {
        #expect(AgentDirective(variantCount: 9).variantCount == 3)
        #expect(AgentDirective(variantCount: 0).variantCount == 1)
        let entry = OutboxEntry(id: "b", createdAt: fixedDate, thread: testThread, items: [], isRepeat: false, state: .readyToSend,
            directive: AgentDirective(mode: .replyOnly, note: "x"))
        let back = try JSONDecoder().decode(OutboxEntry.self, from: JSONEncoder().encode(entry))
        #expect(back.directive == entry.directive)
        // Entries stored before the directive existed still decode.
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any])
        json.removeValue(forKey: "directive")
        let old = try JSONDecoder().decode(OutboxEntry.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.directive == nil)
    }
}
