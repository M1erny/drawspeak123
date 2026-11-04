import SwiftUI
import DrawspeakCore

struct RecordingRow: View {
    let workspace: Workspace
    let note: Note
    let recording: Recording
    let canvasId: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(NotesPresentation.duration(recording.duration), systemImage: "waveform")
                .font(.caption).accessibilityLabel("Recording duration \(NotesPresentation.duration(recording.duration))")
            switch recording.state {
            case .recording:
                Label("Recording", systemImage: "mic.fill")
            case .transcribing:
                ProgressView("Transcribing…")
            case .transcribed:
                Label("Transcribed", systemImage: "checkmark")
                if let transcript = recording.transcript {
                    DisclosureGroup("Raw Transcript") { Text(transcript.text).textSelection(.enabled) }
                        .frame(minHeight: Theme.minTarget)
                    if note.textSource == .typed {
                        Button("Append Transcript", systemImage: "text.append") {
                            workspace.appendTranscript(noteId: note.id, recordingId: recording.id)
                        }.frame(minHeight: Theme.minTarget)
                    }
                }
            case .failed(let code, let mayHaveBeenProcessed):
                Text(NotesPresentation.failure(code))
                if recording.audio != nil {
                    TranscribeAgainButton(workspace: workspace, noteId: note.id, recordingId: recording.id, canvasId: canvasId)
                    if mayHaveBeenProcessed { Text("May be charged again").font(.footnote).foregroundStyle(Theme.secondaryInk) }
                }
            case .interrupted:
                Text(recording.audio != nil ? "Recording ended early; audio kept" : "Recording ended early; no audio was saved")
                if recording.audio != nil { TranscribeAgainButton(workspace: workspace, noteId: note.id, recordingId: recording.id, canvasId: canvasId) }
            case .saved:
                Text("Audio Saved")
                TranscribeAgainButton(workspace: workspace, noteId: note.id, recordingId: recording.id, canvasId: canvasId)
            case .saveFailed:
                Label("The audio could not be stored yet. It is kept on this iPad.", systemImage: "exclamationmark.triangle")
                Button("Try Saving Again", systemImage: "arrow.clockwise") {
                    workspace.retrySavingAudio(RecordingScope(canvasId: canvasId, noteId: note.id, recordingId: recording.id))
                }
                .frame(minHeight: Theme.minTarget)
            }
        }
        .font(.subheadline)
    }


}

#Preview {
    let workspace = NotesPreview.workspace()
    let note = workspace.currentCanvas!.notes[1]
    RecordingRow(workspace: workspace, note: note, recording: note.recordings[0], canvasId: workspace.currentCanvas!.id)
}
