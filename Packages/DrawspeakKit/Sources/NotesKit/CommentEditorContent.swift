import SwiftUI
import DrawspeakCore

struct CommentEditorContent: View {
    let workspace: Workspace
    let note: Note
    @State private var starting = false

    var body: some View {
        VStack(alignment: .leading, spacing: NotesMetrics.sectionSpacing) {
            if let live = workspace.liveText(for: note.id), !live.isEmpty {
                LiveCommentText(text: live, partial: workspace.activeRecording?.noteId == note.id ? workspace.livePartialText : "")
            }
            NoteTextEditor(workspace: workspace, note: note)
            if workspace.activeRecording?.noteId == note.id {
                CompactRecordingRow(workspace: workspace)
            } else {
                Button(action: record) {
                    Label { Text("Record", bundle: .module) } icon: { Image(systemName: "mic") }
                }
                .labelStyle(.iconOnly)
                .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                .disabled(starting || workspace.activeRecording != nil)
            }
            if let canvasId = workspace.currentCanvasId {
                ForEach(note.recordings) { recording in
                    RecordingRow(workspace: workspace, note: note, recording: recording, canvasId: canvasId)
                }
            }
        }
    }

    private func record() {
        starting = true
        Task {
            await workspace.startRecording(noteId: note.id)
            starting = false
        }
    }
}
