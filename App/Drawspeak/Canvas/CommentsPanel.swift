import DrawspeakCore
import NotesKit
import SwiftUI

/// The Comments drawer in regular width: a Liquid Glass panel floating over the canvas.
///
/// It is an overlay, not a column. The canvas keeps its full width underneath and shows through
/// the glass, so no strip of cut-off screens is left beside it; framing keeps the content clear
/// of the panel (`CanvasController.inspectorCoverage`). The list is clipped to the panel's
/// rounded shape, so rows and expanded comments never draw outside it.
struct CommentsPanel: View {
    let workspace: Workspace
    let controller: CanvasController
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ShellMetrics.inspectorPanelCornerRadius, style: .continuous)
        let content = CommentsInspector(workspace: workspace, onShowSource: controller.showSource,
                                        onAddRegion: controller.addRegion, onSend: openFeedback, controls: .header)
            .scrollContentBackground(.hidden)
            .frame(width: ShellMetrics.inspectorWidth.ideal)
            .clipShape(shape)
        Group {
            if reduceTransparency {
                content
                    .background(Theme.surface, in: shape)
                    .overlay { shape.strokeBorder(.separator) }
            } else {
                content.glassEffect(.regular, in: shape)
            }
        }
        .padding(ShellMetrics.inspectorPanelInset)
    }

    private func openFeedback(_ selection: Set<UUID>) {
        controller.openFeedback(selection: selection)
    }
}
