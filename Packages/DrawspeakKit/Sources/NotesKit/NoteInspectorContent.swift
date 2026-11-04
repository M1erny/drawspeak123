import SwiftUI
import DrawspeakCore

struct NoteInspectorContent: View {
    let workspace: Workspace
    let note: Note
    let canvas: ReviewCanvas
    let onShowSource: (UUID) -> Void
    let onClose: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var isStartingVoice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                PinBadge(number: note.ordinal, isActive: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Comment \(note.ordinal)").font(.headline)
                    if let snapshot = canvas.snapshots.first(where: { $0.id == note.snapshotId }) {
                        Text(note.shape.kindLabel + " · " + NotesPresentation.sourceLabel(snapshot, in: canvas)).font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                }
                Spacer(minLength: 0)
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Delete Comment", systemImage: "trash", role: .destructive) {
                        workspace.deleteNote(note.id)
                        onClose()
                    }
                    .disabled(workspace.activeRecording != nil)
                    .accessibilityHint("Deletes comment \(note.ordinal). Undo can restore it.")
                }
                .labelStyle(.iconOnly)
                .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                Button("Close", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly).frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
            }
            ReadinessChip(readiness: FeedbackScope.readiness(of: note, in: canvas, sourceAvailable: workspace.isSourceAvailable))
            NoteTextEditor(workspace: workspace, note: note)
                .id("comment-editor")
            if let issue = workspace.voiceIssue {
                VoicePermissionNotice(issue: issue, onOpenSettings: {
                    if let url = URL(string: "app-settings:") { openURL(url) }
                }, onDismiss: { workspace.clearVoiceIssue() })
            }
            Divider()
            if workspace.activeRecording?.noteId != note.id {
                Button("Record Voice", systemImage: "mic.fill") {
                    isStartingVoice = true
                    Task {
                        await workspace.startRecording(noteId: note.id)
                        isStartingVoice = false
                    }
                }
                .frame(minHeight: Theme.minTarget)
                .disabled(workspace.activeRecording != nil || isStartingVoice)
            } else {
                Label("Recording — use Stop or Discard above", systemImage: "mic.fill").font(.subheadline)
            }
            ForEach(note.recordings) { recording in
                RecordingRow(workspace: workspace, note: note, recording: recording, canvasId: canvas.id)
            }
            if let snapshot = canvas.snapshots.first(where: { $0.id == note.snapshotId }) {
                SnapshotMarkPreview(workspace: workspace, snapshot: snapshot, shape: note.shape, croppedToMark: true, maximumHeight: 180)
                    .frame(maxHeight: 180)
                Button("Show Source on Canvas", systemImage: "scope") { onShowSource(note.id) }
                    .frame(minHeight: Theme.minTarget)
            }
        }
        .padding().foregroundStyle(Theme.ink)
    }
}

#Preview {
    let workspace = NotesPreview.workspace()
    NoteInspectorContent(workspace: workspace, note: workspace.currentCanvas!.notes[0], canvas: workspace.currentCanvas!, onShowSource: { _ in }, onClose: {})
}
