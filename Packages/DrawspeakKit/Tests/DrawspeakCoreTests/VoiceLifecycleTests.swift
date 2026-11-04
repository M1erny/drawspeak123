import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Voice lifecycle (F06, F07, F08, F09)")
struct VoiceLifecycleTests {
    @Test func clearingTextDuringTranscriptionIsNotRefilled() async throws {
        let ws = makeWorkspace()
        ws.voice = FakeVoice()
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "")
        await ws.startRecording(noteId: id)
        let scope = try #require(ws.activeRecording)
        ws.stopRecording()

        ws.updateNoteText(id, text: "typed correction")
        ws.updateNoteText(id, text: "")
        ws.applyTranscript(makeTranscript("late transcript"), scope: scope)

        let note = try #require(ws.note(id))
        #expect(note.text == "")
        #expect(note.textSource == .typed)
        #expect(note.recordings.first?.transcript?.text == "late transcript")
    }

    @Test func clearingBeforeRecordingStartsStillFillsFromTranscript() throws {
        let rec = Recording(startedAt: fixedDate, state: .transcribing, textRevisionAtStart: 3)
        let note = Note(ordinal: 1, snapshotId: "s1", shape: regionShape, text: "", textSource: .typed, revision: 3, recordings: [rec], createdAt: fixedDate, updatedAt: fixedDate)
        var canvas = ReviewCanvas(projectId: UUID(), title: "C", notes: [note], createdAt: fixedDate, updatedAt: fixedDate)
        let scope = RecordingScope(canvasId: canvas.id, noteId: note.id, recordingId: rec.id)

        #expect(TranscriptMerge.apply(makeTranscript("spoken"), scope: scope, to: &canvas, now: fixedDate) == .filledText)
        #expect(canvas.notes[0].text == "spoken")

        // An edit after the start (revision moved on) keeps the person's text, even when empty.
        let rec2 = Recording(startedAt: fixedDate, state: .transcribing, textRevisionAtStart: 4)
        canvas.notes[0].recordings.append(rec2)
        canvas.notes[0].text = ""
        canvas.notes[0].textSource = .typed
        canvas.notes[0].revision = 6
        let scope2 = RecordingScope(canvasId: canvas.id, noteId: note.id, recordingId: rec2.id)
        #expect(TranscriptMerge.apply(makeTranscript("again"), scope: scope2, to: &canvas, now: fixedDate) == .keptTypedText)
        #expect(canvas.notes[0].text == "")
    }

    @Test func repeatedTranscribeWhileInFlightSendsOneRequest() async throws {
        let ws = makeWorkspace()
        let voice = FakeVoice()
        // Live transcription fails after Stop, so the batch fallback runs.
        voice.eventsAfterStop = [.failed(code: "network")]
        ws.voice = voice
        let transcriber = FakeTranscriber(text: "hello there")
        ws.transcriber = transcriber
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "")
        await ws.startRecording(noteId: id)
        let scope = try #require(ws.activeRecording)

        ws.stopRecording()
        #expect(ws.note(id)?.recordings.first?.state == .transcribing)
        #expect(ws.isTranscriptionInFlight(scope))
        ws.transcribe(scope)
        ws.transcribe(scope)

        #expect(await waitUntil { ws.note(id)?.recordings.first?.state == .transcribed })
        try await Task.sleep(for: .milliseconds(100))
        #expect(transcriber.calls == 1)
        #expect(ws.note(id)?.text == "hello there")
        #expect(!ws.isTranscriptionInFlight(scope))
    }

    @Test func audioSaveFailureKeepsTheTemporaryFileUntilRetrySucceeds() async throws {
        let ws = makeWorkspace()
        let voice = FakeVoice()
        ws.voice = voice
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "")
        await ws.startRecording(noteId: id)
        let scope = try #require(ws.activeRecording)

        try setWritable(ws.blobs.root, false)
        ws.stopRecording()
        try setWritable(ws.blobs.root, true)

        let file = try #require(voice.lastFile)
        let recording = try #require(ws.note(id)?.recordings.first)
        #expect(recording.state == .saveFailed(tempPath: file.path(percentEncoded: false)))
        #expect(recording.audio == nil)
        #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
        await ws.saveNow()
        #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))

        ws.retrySavingAudio(scope)

        let saved = try #require(ws.note(id)?.recordings.first)
        let audio = try #require(saved.audio)
        #expect(ws.blobs.exists(audio))
        await ws.saveNow()
        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    }

    @Test func undoAddNoteDuringCaptureStopsCaptureAndRedoRestoresNoLiveRecording() async throws {
        let ws = makeWorkspace()
        let voice = FakeVoice()
        ws.voice = voice
        try addImage(ws, id: "s1")
        let undo = UndoManager()
        undo.groupsByEvent = false
        ws.undoManager = undo

        undo.beginUndoGrouping()
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        undo.endUndoGrouping()
        #expect(await waitUntil { ws.activeRecording != nil })
        #expect(ws.note(id)?.isRecording == true)

        undo.undo()
        #expect(ws.note(id) == nil)
        #expect(ws.activeRecording == nil)
        #expect(voice.discardCount == 1)
        #expect(!voice.isRecording)
        #expect(undo.canRedo)

        undo.redo()
        let restored = try #require(ws.note(id))
        #expect(!restored.isRecording)
        #expect(restored.recordings.map(\.state) == [.interrupted])
        #expect(ws.activeRecording == nil)

        undo.undo()
        #expect(ws.note(id) == nil)
    }

    @Test func discardingTheOnlyRecordingRemovesTheEmptyNoteWithOneUndo() async throws {
        let ws = makeWorkspace()
        ws.voice = FakeVoice()
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "")
        await ws.startRecording(noteId: id)
        let undo = UndoManager()
        undo.groupsByEvent = false
        ws.undoManager = undo

        undo.beginUndoGrouping()
        ws.discardRecording()
        undo.endUndoGrouping()
        #expect(ws.note(id) == nil)

        undo.undo()
        let restored = try #require(ws.note(id))
        #expect(restored.recordings.isEmpty)
        #expect(!undo.canUndo)
    }
}
