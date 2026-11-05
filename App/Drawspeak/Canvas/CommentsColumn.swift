import DrawspeakCore
import NotesKit
import SwiftUI

/// The Comments inspector as a sheet in compact width. In regular width Comments are a floating
/// panel over the canvas instead (`CommentsPanel`).
struct CommentsColumn: View {
    let workspace: Workspace
    let controller: CanvasController

    var body: some View {
        NavigationStack {
            CommentsInspector(workspace: workspace, onShowSource: controller.showSource, onAddRegion: controller.addRegion,
                              onSend: openFeedback)
                .navigationTitle("Comments")
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    private func openFeedback(_ selection: Set<UUID>) {
        controller.openFeedback(selection: selection)
    }
}
