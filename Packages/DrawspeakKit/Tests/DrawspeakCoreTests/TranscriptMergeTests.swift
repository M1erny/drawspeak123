import DrawspeakCore
import Foundation
import Testing

@Suite("TranscriptMerge (AC-13)")
struct TranscriptMergeTests {
    /// A canvas with one note holding the given recordings.
    private func makeCanvas(text: String = "", source: TextSource = .none, recordings: [Recording]) -> (ReviewCanvas, Note) {
        let note = Note(
            ordinal: 1, snapshotId: "s1", shape: regionShape, text: text, textSource: source,
            recordings: recordings, createdAt: fixedDate, updatedAt: fixedDate
        )
        let canvas = ReviewCanvas(projectId: UUID(), title: "C", notes: [note], nextOrdinal: 2, createdAt: fixedDate, updatedAt: fixedDate)
        return (canvas, note)
    }

    private func recording(_ state: RecordingState = .transcribing) -> Recording {
        Recording(startedAt: fixedDate, state: state)
    }

    @Test func emptyNoteIsFilledWithTranscript() throws {
        let rec = recording()
        var (canvas, note) = makeCanvas(recordings: [rec])
        let scope = RecordingScope(canvasId: canvas.id, noteId: note.id, recordingId: rec.id)

        let outcome = TranscriptMerge.apply(makeTranscript("  Make it blue  "), scope: scope, to: &canvas, now: fixedDate)

        #expect(outcome == .filledText)
        let updated = canvas.notes[0]
        #expect(updated.text == "Make it blue")
        #expect(updated.textSource == .transcript)
        #expect(updated.revision == note.revision + 1)
        #expect(updated.recordings[0].state == .transcribed)
        #expect(updated.recordings[0].transcript?.text == "  Make it blue  ")
    }

    @Test func typedTextIsKeptAndTranscriptIsStoredOnRecording() throws {
        let rec = recording()
        var (canvas, note) = makeCanvas(text: "My own words", source: .typed, recordings: [rec])
        let scope = RecordingScope(canvasId: canvas.id, noteId: note.id, recordingId: rec.id)

        let outcome = TranscriptMerge.apply(makeTranscript("something else"), scope: scope, to: &canvas, now: fixedDate)

        #expect(outcome == .keptTypedText)
        let updated = canvas.notes[0]
        #expect(updated.text == "My own words")
        #expect(updated.textSource == .typed)
        #expect(updated.revision == note.revision)
        #expect(updated.recordings[0].transcript?.text == "something else")
    }

    @Test func deletedNoteDiscardsResultAndLeavesCanvasUnchanged() throws {
        let rec = recording()
        var (canvas, note) = makeCanvas(recordings: [rec])
        let scope = RecordingScope(canvasId: canvas.id, noteId: note.id, recordingId: rec.id)
        canvas.notes.removeAll()
        let before = canvas

        let outcome = TranscriptMerge.apply(makeTranscript("late"), scope: scope, to: &canvas, now: fixedDate.addingTimeInterval(99))

        #expect(outcome == .discarded)
        #expect(canvas == before)
    }

    @Test func otherCanvasScopeIsDiscarded() throws {
        let rec = recording()
        var (canvas, note) = makeCanvas(recordings: [rec])
        let scope = RecordingScope(canvasId: UUID(), noteId: note.id, recordingId: rec.id)
        let before = canvas

        let outcome = TranscriptMerge.apply(makeTranscript("wrong canvas"), scope: scope, to: &canvas, now: fixedDate)

        #expect(outcome == .discarded)
        #expect(canvas == before)
    }

    @Test func olderRecordingDoesNotChangeTextWhenNewerRecordingExists() throws {
        let old = recording()
        let newer = recording(.recording)
        var (canvas, note) = makeCanvas(recordings: [old, newer])
        let scope = RecordingScope(canvasId: canvas.id, noteId: note.id, recordingId: old.id)

        _ = TranscriptMerge.apply(makeTranscript("stale transcript"), scope: scope, to: &canvas, now: fixedDate)

        let updated = canvas.notes[0]
        #expect(updated.text == "")
        #expect(updated.textSource == TextSource.none)
        #expect(updated.revision == note.revision)
        #expect(updated.recordings[0].transcript?.text == "stale transcript")
        #expect(updated.recordings[1].state == .recording)
    }
}
