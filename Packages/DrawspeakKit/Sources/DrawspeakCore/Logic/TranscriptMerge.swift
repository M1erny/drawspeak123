import Foundation

/// Identity captured when a recording starts. Late results use only this scope.
public struct RecordingScope: Codable, Hashable, Sendable {
    public var canvasId: UUID
    public var noteId: UUID
    public var recordingId: UUID

    public init(canvasId: UUID, noteId: UUID, recordingId: UUID) {
        self.canvasId = canvasId
        self.noteId = noteId
        self.recordingId = recordingId
    }
}

public enum TranscriptMergeOutcome: Equatable, Sendable {
    /// The note text now equals the transcript.
    case filledText
    /// The person's text was kept; the transcript is stored on the recording.
    case keptTypedText
    /// The note or recording no longer exists; nothing changed.
    case discarded
}

public enum TranscriptMerge {
    /// Applies a transcript to the scoped recording without overwriting newer work.
    public static func apply(_ transcript: Transcript, scope: RecordingScope, to canvas: inout ReviewCanvas, now: Date) -> TranscriptMergeOutcome {
        guard canvas.id == scope.canvasId,
              let noteIndex = canvas.notes.firstIndex(where: { $0.id == scope.noteId }),
              let recordingIndex = canvas.notes[noteIndex].recordings.firstIndex(where: { $0.id == scope.recordingId })
        else { return .discarded }
        var note = canvas.notes[noteIndex]
        note.recordings[recordingIndex].transcript = transcript
        note.recordings[recordingIndex].state = .transcribed
        // A newer recording on the same note owns the text.
        let isLatestRecording = recordingIndex == note.recordings.count - 1
        let outcome: TranscriptMergeOutcome
        let text = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let recording = note.recordings[recordingIndex]
        let mayFill: Bool
        if let startRevision = recording.textRevisionAtStart {
            // Any text change since the recording started is newer user work,
            // including clearing the text. Typed text from before is kept too.
            let editedSinceStart = note.revision != startRevision
            mayFill = !editedSinceStart && !(note.textSource == .typed && note.hasText)
        } else {
            mayFill = note.textSource != .typed
        }
        if isLatestRecording, mayFill, !text.isEmpty {
            if note.textSource == .transcript, note.hasText {
                // Several recordings without typing: keep previous transcripts and add this one.
                note.text = note.trimmedText + "\n" + text
            } else {
                note.text = text
            }
            note.textSource = .transcript
            note.revision += 1
            outcome = .filledText
        } else {
            outcome = .keptTypedText
        }
        note.updatedAt = now
        canvas.notes[noteIndex] = note
        canvas.updatedAt = now
        return outcome
    }
}
