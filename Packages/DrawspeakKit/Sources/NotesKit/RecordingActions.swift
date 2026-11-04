import SwiftUI
import DrawspeakCore

struct RecordingActions: View {
    let workspace: Workspace
    var body: some View {
        Button(action: workspace.stopRecording) {
            Label { Text("Stop", bundle: .module) } icon: { Image(systemName: "stop.fill") }
        }
        .tint(.red)
        .keyboardShortcut(.space, modifiers: [])
        .frame(minHeight: Theme.minTarget)
    }
}
