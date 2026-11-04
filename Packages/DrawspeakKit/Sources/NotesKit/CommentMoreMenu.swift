import SwiftUI
import DrawspeakCore

struct CommentMoreMenu: View {
    let workspace: Workspace
    let note: Note
    @State private var transcriptRecording: Recording?
    @State private var showsOriginal = false

    var body: some View {
        Menu {
            if workspace.activeRecording?.noteId == note.id {
                Button(role: .destructive, action: workspace.discardRecording) {
                    Text("Discard", bundle: .module)
                }
            }
            if note.hasText, workspace.refiner?.isConfigured == true {
                Button(action: refine) {
                    Label { Text("Refine with Claude", bundle: .module) } icon: { Image(systemName: "sparkles") }
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
            if note.refinement != nil {
                Button { showsOriginal = true } label: { Text("Show Original", bundle: .module) }
            }
        } label: {
            Label { Text("More", bundle: .module) } icon: { Image(systemName: "ellipsis") }
        }
        .sheet(item: $transcriptRecording) { recording in
            TranscriptSheet(text: recording.transcript?.text ?? "")
        }
        .sheet(isPresented: $showsOriginal) {
            OriginalCommentSheet(text: note.refinement?.rawText ?? "")
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
    }

    private func refine() { workspace.refine(noteId: note.id) }
    private func showTranscript(_ recording: Recording) { transcriptRecording = recording }
    private func append(_ recording: Recording) { workspace.appendTranscript(noteId: note.id, recordingId: recording.id) }
}
