import SwiftUI
import DrawspeakCore

struct CommentMoreMenu: View {
    let workspace: Workspace
    let note: Note
    let onShowSource: (UUID) -> Void
    @State private var transcriptRecording: Recording?

    var body: some View {
        Menu {
            Button(action: showSource) {
                Label { Text("Show on Canvas", bundle: .module) } icon: { Image(systemName: "scope") }
            }
            if workspace.activeRecording?.noteId == note.id {
                Button(role: .destructive, action: workspace.discardRecording) {
                    Text("Discard", bundle: .module)
                }
            }
            ForEach(note.recordings.filter { $0.transcript != nil }) { recording in
                Menu {
                    Button { showTranscript(recording) } label: { Text("Transcript", bundle: .module) }
                    if note.textSource == .typed {
                        Button { append(recording) } label: { Text("Add to Comment", bundle: .module) }
                    }
                } label: {
                    Text("Recording · \(NotesPresentation.duration(recording.duration))", bundle: .module)
                }
            }
            Button(role: .destructive, action: delete) {
                Label { Text("Delete", bundle: .module) } icon: { Image(systemName: "trash") }
            }
            .disabled(note.isRecording || workspace.activeRecording?.noteId == note.id)
        } label: {
            Label { Text("More", bundle: .module) } icon: { Image(systemName: "ellipsis") }
        }
        .sheet(item: $transcriptRecording) { recording in
            TranscriptSheet(text: recording.transcript?.text ?? "")
        }
        .labelStyle(.iconOnly)
        .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
    }

    private func showTranscript(_ recording: Recording) { transcriptRecording = recording }
    private func append(_ recording: Recording) { workspace.appendTranscript(noteId: note.id, recordingId: recording.id) }
    private func showSource() { onShowSource(note.id) }
    private func delete() { workspace.deleteNote(note.id) }
}
