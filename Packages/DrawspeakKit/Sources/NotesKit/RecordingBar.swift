import SwiftUI
import DrawspeakCore

public struct RecordingBar: View {
    private let workspace: Workspace

    public init(workspace: Workspace) { self.workspace = workspace }

    public var body: some View {
        if let scope = workspace.activeRecording,
           let note = workspace.note(scope.noteId, canvasId: scope.canvasId) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    RecordingStatus(workspace: workspace, number: note.ordinal)
                    RecordingActions(workspace: workspace)
                }
                VStack(alignment: .leading) {
                    RecordingStatus(workspace: workspace, number: note.ordinal)
                    RecordingActions(workspace: workspace)
                }
            }
            .padding(12).paletteBackground()
        }
    }
}

#Preview {
    RecordingBar(workspace: NotesPreview.workspace(recording: true))
}
