import DrawspeakCore
import NotesKit
import SwiftUI

/// The Comments inspector: a trailing column, or a sheet in compact width.
///
/// In the column its toolbar items join the canvas toolbar above the inspector, so it
/// sets no title and has no navigation stack of its own; the sheet gets both.
struct CommentsColumn: View {
    let workspace: Workspace
    let controller: CanvasController
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                NavigationStack {
                    inspector
                        .navigationTitle("Comments")
                        .navigationBarTitleDisplayMode(.inline)
                }
            } else if controller.showsInspector {
                // Built only while shown, so its toolbar items never reach a closed column.
                // A floating glass panel over the canvas color, like the canvas sidebar,
                // instead of the opaque grouped-list column.
                inspector
                    .scrollContentBackground(.hidden)
                    .background {
                        InspectorPanelBackground()
                            .padding(ShellMetrics.inspectorPanelInset)
                            .ignoresSafeArea(.container, edges: .vertical)
                    }
                    .background { Theme.canvas.ignoresSafeArea() }
            }
        }
        .inspectorColumnWidth(min: ShellMetrics.inspectorWidth.min, ideal: ShellMetrics.inspectorWidth.ideal,
                              max: ShellMetrics.inspectorWidth.max)
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    private var inspector: some View {
        CommentsInspector(workspace: workspace, onShowSource: controller.showSource, onAddRegion: controller.addRegion,
                          onSend: openFeedback)
    }

    private func openFeedback(_ selection: Set<UUID>) {
        controller.openFeedback(selection: selection)
    }
}

/// Liquid Glass behind the Comments column; a solid surface with Reduce Transparency.
private struct InspectorPanelBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ShellMetrics.inspectorPanelCornerRadius, style: .continuous)
        if reduceTransparency {
            shape.fill(Theme.surface)
        } else {
            shape.fill(.clear).glassEffect(.regular, in: shape)
        }
    }
}
