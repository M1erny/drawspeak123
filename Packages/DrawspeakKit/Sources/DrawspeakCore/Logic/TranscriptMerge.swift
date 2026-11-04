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
        let previousLiveText = note.recordings[recordingIndex].transcript?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        note.recordings[recordingIndex].transcript = transcript
        note.recordings[recordingIndex].state = .transcribed
        // A newer recording on the same note owns the text.
        let isLatestRecording = recordingIndex == note.recordings.count - 1
        let outcome: TranscriptMergeOutcome
        let text = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let recording = note.recordings[recordingIndex]
        if let liveRevision = recording.liveTextRevision, note.revision == liveRevision,
           !previousLiveText.isEmpty, note.trimmedText.hasSuffix(previousLiveText) {
            // Live segments from this recording are still the end of the text and no
            // one edited since: the complete transcript replaces them.
            if isLatestRecording, !text.isEmpty {
                let prefix = String(note.trimmedText.dropLast(previousLiveText.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                note.text = prefix.isEmpty ? text : prefix + "\n" + text
                note.revision += 1
                note.recordings[recordingIndex].liveTextRevision = note.revision
                outcome = .filledText
            } else {
                outcome = .keptTypedText
            }
            note.updatedAt = now
            canvas.notes[noteIndex] = note
            canvas.updatedAt = now
            return outcome
        }
        let mayFill: Bool
        if let startRevision = recording.liveTextRevision ?? recording.textRevisionAtStart {
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

extension TranscriptMerge {
    /// Adds one committed live segment. `transcript` is the running transcript
    /// (every committed segment so far) and is always stored on the recording.
    /// The segment is added to the note text only while no one edited the text since
    /// the recording started (or since the previous live segment), the note had no
    /// typed text before, and this is the newest recording on the note.
    public static func applyLiveSegment(
        _ segment: String,
        transcript: Transcript,
        scope: RecordingScope,
        to canvas: inout ReviewCanvas,
        now: Date
    ) -> TranscriptMergeOutcome {
        guard canvas.id == scope.canvasId,
              let noteIndex = canvas.notes.firstIndex(where: { $0.id == scope.noteId }),
              let recordingIndex = canvas.notes[noteIndex].recordings.firstIndex(where: { $0.id == scope.recordingId })
        else { return .discarded }
        var note = canvas.notes[noteIndex]
        var recording = note.recordings[recordingIndex]
        recording.transcript = transcript

        let text = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        let isLatestRecording = recordingIndex == note.recordings.count - 1
        let continuing = recording.liveTextRevision != nil
        let baseline = recording.liveTextRevision ?? recording.textRevisionAtStart
        let untouched = baseline.map { note.revision == $0 } ?? (note.textSource != .typed)
        let typedBefore = !continuing && note.textSource == .typed && note.hasText
        let outcome: TranscriptMergeOutcome
        if isLatestRecording, untouched, !typedBefore, !text.isEmpty {
            if continuing {
                note.text = note.trimmedText + " " + text
            } else if note.textSource == .transcript, note.hasText {
                // An earlier recording's transcript stays; this one starts a new line.
                note.text = note.trimmedText + "\n" + text
            } else {
                note.text = text
            }
            note.textSource = .transcript
            note.revision += 1
            recording.liveTextRevision = note.revision
            outcome = .filledText
        } else {
            outcome = .keptTypedText
        }
        note.recordings[recordingIndex] = recording
        note.updatedAt = now
        canvas.notes[noteIndex] = note
        canvas.updatedAt = now
        return outcome
    }

    /// Stores the final live transcript and marks the recording transcribed. The
    /// text is not touched: committed segments were already added one by one.
    public static func finishLive(_ transcript: Transcript, scope: RecordingScope, to canvas: inout ReviewCanvas, now: Date) -> Bool {
        guard canvas.id == scope.canvasId,
              let noteIndex = canvas.notes.firstIndex(where: { $0.id == scope.noteId }),
              let recordingIndex = canvas.notes[noteIndex].recordings.firstIndex(where: { $0.id == scope.recordingId })
        else { return false }
        canvas.notes[noteIndex].recordings[recordingIndex].transcript = transcript
        canvas.notes[noteIndex].recordings[recordingIndex].state = .transcribed
        canvas.notes[noteIndex].updatedAt = now
        canvas.updatedAt = now
        return true
    }
}
