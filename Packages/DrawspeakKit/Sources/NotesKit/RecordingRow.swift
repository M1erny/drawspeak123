import SwiftUI
import DrawspeakCore

struct RecordingRow: View {
    let workspace: Workspace
    let note: Note
    let recording: Recording
    let canvasId: UUID
    private var scope: RecordingScope { RecordingScope(canvasId: canvasId, noteId: note.id, recordingId: recording.id) }

    var body: some View {
        Group {
            switch recording.state {
            case .recording, .transcribed: EmptyView()
            case .transcribing:
                Text("Transcribing…", bundle: .module)
            case .saveFailed:
                HStack {
                    Text("Audio not saved", bundle: .module)
                    Button(action: retrySave) { Text("Retry", bundle: .module) }
                        .frame(minHeight: Theme.minTarget)
                }
            case .interrupted:
                HStack {
                    if recording.audio == nil { Text("Recording lost", bundle: .module) }
                    else {
                        Text("Interrupted", bundle: .module)
                        Button(action: retry) { Text("Retry", bundle: .module) }
                            .frame(minHeight: Theme.minTarget)
                            .disabled(workspace.isTranscriptionInFlight(scope))
                    }
                }
            case .saved:
                Button(action: retry) { Text("Transcribe Again", bundle: .module) }
                    .frame(minHeight: Theme.minTarget)
                    .disabled(workspace.isTranscriptionInFlight(scope))
            case .failed:
                VStack(alignment: .leading) {
                    HStack {
                        Text("Transcription failed", bundle: .module)
                        if recording.audio != nil {
                            Button(action: retry) { Text("Retry", bundle: .module) }
                                .frame(minHeight: Theme.minTarget)
                                .disabled(workspace.isTranscriptionInFlight(scope))
                        }
                    }
                    if case .failed(_, let mayHaveBeenProcessed) = recording.state, mayHaveBeenProcessed {
                        Text("May be billed again", bundle: .module).font(.caption)
                    }
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func retry() { workspace.transcribe(scope) }
    private func retrySave() { workspace.retrySavingAudio(scope) }
}
