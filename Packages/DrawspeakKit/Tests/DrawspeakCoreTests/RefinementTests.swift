import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Refine with Claude")
struct RefinementTests {
    private func setUp(
        refiner: FakeRefiner? = FakeRefiner(), transcriber: FakeTranscriber = FakeTranscriber(text: "batch words")
    ) throws -> (Workspace, FakeVoice) {
        let ws = makeWorkspace()
        let voice = FakeVoice()
        ws.voice = voice
        ws.transcriber = transcriber
        ws.refiner = refiner
        ws.refinerModelId = "claude-sonnet-5-5"
        try addImage(ws, id: "s1")
        return (ws, voice)
    }

    /// Records one live recording on a new region note and finishes it.
    private func recordLive(_ ws: Workspace, _ voice: FakeVoice, text: String = "ten przycisk jest za mały") throws -> UUID {
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        voice.emit(.committed(text))
        ws.stopRecording()
        voice.emit(.finished(text))
        return id
    }

    @Test func finalLiveTranscriptIsRefinedOnceAndReplacesTheText() async throws {
        let refiner = FakeRefiner()
        let (ws, voice) = try setUp(refiner: refiner)
        var rendered: [UUID] = []
        ws.regionImage = { note, snapshot in
            rendered.append(note.id)
            return Data("png-\(snapshot.id)".utf8)
        }
        let id = try recordLive(ws, voice)
        let revisionAfterTranscript = try #require(ws.note(id)?.revision)
        #expect(ws.note(id)?.refinement?.state == .refining)
        #expect(ws.note(id)?.isRefining == true)

        #expect(await waitUntil { ws.note(id)?.refinement?.state == .refined })
        let note = try #require(ws.note(id))
        #expect(note.text == "Refined comment.")
        #expect(note.textSource == .transcript)
        #expect(note.revision == revisionAfterTranscript + 1)
        #expect(note.refinement?.rawText == "ten przycisk jest za mały")
        #expect(note.refinement?.text == "Refined comment.")
        #expect(note.refinement?.modelId == "claude-sonnet-5-5")
        #expect(note.refinement?.recordingId == note.recordings.first?.id)
        #expect(note.unusedRefinedText == nil)
        // The raw transcript stays on the recording.
        #expect(note.recordings.first?.transcript?.text == "ten przycisk jest za mały")

        let request = try #require(refiner.requests.first)
        #expect(refiner.calls == 1)
        #expect(request.transcript == "ten przycisk jest za mały")
        #expect(request.regionPNG == Data("png-s1".utf8))
        #expect(request.context == RefineContext(screenTitle: "s1", versionLabel: "Now", markKind: "Region", componentLabel: nil, language: nil))
        #expect(rendered == [id])
    }

    @Test func batchTranscriptIsRefined() async throws {
        let refiner = FakeRefiner()
        let (ws, voice) = try setUp(refiner: refiner)
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        voice.emit(.failed(code: "network"))
        ws.stopRecording()
        #expect(await waitUntil { ws.note(id)?.refinement?.state == .refined })
        #expect(ws.note(id)?.text == "Refined comment.")
        #expect(refiner.requests.map(\.transcript) == ["batch words"])
        #expect(ws.note(id)?.recordings.first?.transcript?.text == "batch words")
    }

    @Test func typingDuringTheRequestKeepsTypedTextAndOffersTheRefinement() async throws {
        let refiner = FakeRefiner(delay: .milliseconds(60))
        let (ws, voice) = try setUp(refiner: refiner)
        let id = try recordLive(ws, voice)
        ws.updateNoteText(id, text: "my own words")
        #expect(await waitUntil { ws.note(id)?.refinement?.state == .refined })
        #expect(ws.note(id)?.text == "my own words")
        #expect(ws.note(id)?.textSource == .typed)
        #expect(ws.note(id)?.unusedRefinedText == "Refined comment.")

        let before = try #require(ws.note(id)?.revision)
        ws.useRefinedText(noteId: id)
        #expect(ws.note(id)?.text == "Refined comment.")
        #expect(ws.note(id)?.textSource == .transcript)
        #expect(ws.note(id)?.revision == before + 1)
        #expect(ws.note(id)?.unusedRefinedText == nil)
        #expect(refiner.calls == 1)
    }

    @Test func typingDuringTheRecordingSkipsAutomaticRefinement() async throws {
        let refiner = FakeRefiner()
        let (ws, voice) = try setUp(refiner: refiner)
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        voice.emit(.committed("spoken"))
        ws.updateNoteText(id, text: "typed")
        ws.stopRecording()
        voice.emit(.finished("spoken"))
        try await Task.sleep(for: .milliseconds(60))
        #expect(refiner.calls == 0)
        #expect(ws.note(id)?.refinement == nil)
        #expect(ws.note(id)?.text == "typed")
    }

    @Test func disabledOrUnconfiguredRefinementDoesNothingAutomatically() async throws {
        let refiner = FakeRefiner()
        let (ws, voice) = try setUp(refiner: refiner)
        ws.refineEnabled = { false }
        let first = try recordLive(ws, voice)
        ws.refineEnabled = { true }
        ws.refiner = FakeRefiner(isConfigured: false)
        let second = try recordLive(ws, voice)
        try await Task.sleep(for: .milliseconds(60))
        #expect(refiner.calls == 0)
        #expect(ws.note(first)?.refinement == nil)
        #expect(ws.note(second)?.refinement == nil)
        #expect(ws.note(second)?.text == "ten przycisk jest za mały")
    }

    @Test func failureKeepsTheTextAndIsNotRetried() async throws {
        let refiner = FakeRefiner(result: .failure(RefineFailure(code: .rateLimited)))
        let (ws, voice) = try setUp(refiner: refiner)
        let id = try recordLive(ws, voice)
        #expect(await waitUntil { ws.note(id)?.refinement?.state == .failed(code: "rate_limited") })
        try await Task.sleep(for: .milliseconds(60))
        #expect(refiner.calls == 1)
        #expect(ws.note(id)?.text == "ten przycisk jest za mały")
        #expect(!ws.isRefinementInFlight(noteId: id))
    }

    @Test func emptyRefinedTextIsAFailure() async throws {
        let (ws, voice) = try setUp(refiner: FakeRefiner(result: .success("  \n")))
        let id = try recordLive(ws, voice)
        #expect(await waitUntil { ws.note(id)?.refinement?.state == .failed(code: "invalid_response") })
        #expect(ws.note(id)?.text == "ten przycisk jest za mały")
    }

    @Test func manualRefineWorksOnTypedNotesOncePerRequest() async throws {
        let refiner = FakeRefiner(delay: .milliseconds(40))
        let (ws, _) = try setUp(refiner: refiner)
        let id = addTextNote(ws, snapshotId: "s1", text: "make it pop", shape: arrowShape)
        ws.refine(noteId: id)
        ws.refine(noteId: id)
        #expect(ws.isRefinementInFlight(noteId: id))
        #expect(await waitUntil { ws.note(id)?.refinement?.state == .refined })
        #expect(refiner.calls == 1)
        #expect(refiner.requests.first?.context.markKind == "Arrow")
        #expect(ws.note(id)?.text == "Refined comment.")
        #expect(ws.note(id)?.refinement?.recordingId == nil)
    }

    @Test func manualRefineWithoutRefinerReportsNotConfigured() throws {
        let (ws, _) = try setUp(refiner: nil)
        let id = addTextNote(ws, snapshotId: "s1", text: "x")
        ws.refine(noteId: id)
        #expect(ws.note(id)?.refinement?.state == .failed(code: "not_configured"))
        #expect(ws.note(id)?.text == "x")
        let empty = addTextNote(ws, snapshotId: "s1", text: "")
        ws.refine(noteId: empty)
        #expect(ws.note(empty)?.refinement == nil)
    }

    @Test func lateResultForADeletedNoteIsDiscarded() async throws {
        let refiner = FakeRefiner(delay: .milliseconds(30))
        let (ws, voice) = try setUp(refiner: refiner)
        let id = try recordLive(ws, voice)
        let undo = UndoManager()
        undo.groupsByEvent = false
        ws.undoManager = undo
        undo.beginUndoGrouping()
        ws.deleteNote(id)
        undo.endUndoGrouping()
        #expect(await waitUntil { refiner.calls == 1 && !ws.isRefinementInFlight(noteId: id) })
        #expect(ws.note(id) == nil)
        undo.undo()
        let restored = try #require(ws.note(id))
        #expect(restored.refinement?.state == .failed(code: "interrupted"))
        #expect(restored.text == "ten przycisk jest za mały")
    }

    @Test func aRefinementInterruptedByARestartBecomesFailed() throws {
        let project = Project(name: "P", createdAt: fixedDate)
        let note = Note(
            ordinal: 1, snapshotId: "s1", shape: regionShape, text: "raw",
            refinement: Refinement(state: .refining, rawText: "raw", at: fixedDate), createdAt: fixedDate, updatedAt: fixedDate
        )
        let canvas = ReviewCanvas(projectId: project.id, title: "C", notes: [note], nextOrdinal: 2, createdAt: fixedDate, updatedAt: fixedDate)
        let root = makeTempRoot()
        let locations = StorageLocations(root: root)
        let ws = Workspace(
            document: LibraryDocument(projects: [project], canvases: [canvas], lastCanvasId: canvas.id),
            blobs: BlobStore(root: locations.blobs), store: LibraryStore(fileURL: locations.libraryFile), defaults: makeTestDefaults()
        )
        #expect(ws.note(note.id)?.refinement?.state == .failed(code: "interrupted"))
    }
}
