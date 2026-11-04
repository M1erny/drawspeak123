import DrawspeakCore
import NotesKit
import SwiftUI

/// The Comments inspector: a trailing column, or a sheet in compact width.
struct CommentsColumn: View {
    let workspace: Workspace
    let controller: CanvasController

    var body: some View {
        NavigationStack {
            CommentsInspector(workspace: workspace, onShowSource: controller.showSource, onAddRegion: controller.addRegion)
                .navigationBarTitleDisplayMode(.inline)
        }
        .inspectorColumnWidth(min: ShellMetrics.inspectorWidth.min, ideal: ShellMetrics.inspectorWidth.ideal,
                              max: ShellMetrics.inspectorWidth.max)
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}
