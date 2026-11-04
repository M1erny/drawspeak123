import SwiftUI
import DrawspeakCore

struct NoteListRow: View {
    let workspace: Workspace
    let canvas: ReviewCanvas
    let note: Note

    var body: some View {
        HStack(alignment: .top) {
            PinBadge(number: note.ordinal, isActive: workspace.focusedNoteId == note.id)
            VStack(alignment: .leading, spacing: 6) {
                Text(note.hasText ? String(note.trimmedText.split(separator: "\n").first ?? "") : "No comment yet")
                    .lineLimit(2).foregroundStyle(Theme.ink)
                ReadinessChip(readiness: FeedbackScope.readiness(of: note, in: canvas, sourceAvailable: workspace.isSourceAvailable))
            }
            Spacer(minLength: 0)
            if note.isTranscribing {
                Image(systemName: "waveform").accessibilityLabel("Transcribing")
            } else if !note.recordings.isEmpty {
                Image(systemName: note.isRecording ? "mic.fill" : "mic").accessibilityLabel(note.isRecording ? "Recording" : "Has voice recording")
            }
            Image(systemName: "scope")
                .foregroundStyle(Theme.action)
                .accessibilityLabel("Show on Canvas")
        }
        .frame(minHeight: Theme.minTarget).accessibilityElement(children: .combine)
        .accessibilityHint("Shows this comment on the canvas and opens its inspector")
    }
}

#Preview {
    let workspace = NotesPreview.workspace()
    NoteListRow(workspace: workspace, canvas: workspace.currentCanvas!, note: workspace.currentCanvas!.notes[0])
}
