import SwiftUI
import DrawspeakCore

struct TranscribeAgainButton: View {
    let workspace: Workspace
    let noteId: UUID
    let recordingId: UUID
    let canvasId: UUID

    var body: some View {
        Button("Transcribe Again", systemImage: "arrow.clockwise") {
            workspace.transcribe(RecordingScope(canvasId: canvasId, noteId: noteId, recordingId: recordingId))
        }.frame(minHeight: Theme.minTarget)
    }
}

#Preview {
    TranscribeAgainButton(workspace: NotesPreview.workspace(), noteId: UUID(), recordingId: UUID(), canvasId: UUID())
}
