import SwiftUI
import DrawspeakCore

struct RecordingActions: View {
    let workspace: Workspace

    var body: some View {
        HStack {
            Button("Stop", systemImage: "stop.fill") { workspace.stopRecording() }
                .buttonStyle(.borderedProminent).tint(Theme.action)
                .keyboardShortcut(.space, modifiers: [])
                .accessibilityHint("Saves audio and starts transcription")
            Button("Discard", systemImage: "xmark") { workspace.discardRecording() }
                .buttonStyle(.bordered)
                .accessibilityHint("Removes this recording and its empty region. Undo can restore the region.")
        }
        .buttonBorderShape(.capsule).controlSize(.large)
    }
}

#Preview { RecordingActions(workspace: NotesPreview.workspace()) }
