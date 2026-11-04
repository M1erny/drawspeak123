import SwiftUI
import DrawspeakCore

struct CommentEditorContent: View {
    let workspace: Workspace
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: NotesMetrics.sectionSpacing) {
            if let live = workspace.liveText(for: note.id) {
                LiveCommentText(text: live, partial: workspace.activeRecording?.noteId == note.id ? workspace.livePartialText : "")
            } else if workspace.activeRecording?.noteId == note.id {
                LiveCommentText(text: "", partial: "")
            } else {
                NoteTextEditor(workspace: workspace, note: note)
            }
            CommentRefinementStatus(workspace: workspace, note: note)
            if workspace.activeRecording?.noteId == note.id {
                RecordingStatus(workspace: workspace)
            }
            if let canvasId = workspace.currentCanvasId {
                ForEach(note.recordings) { recording in
                    RecordingRow(workspace: workspace, note: note, recording: recording, canvasId: canvasId)
                }
            }
        }
    }

}
