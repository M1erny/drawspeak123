#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

struct CanvasContent: View {
    let bubbleInsets: EdgeInsets
    let workspace: Workspace
    let tool: CanvasTool
    let interaction: CanvasInteraction
    let presentation: CanvasPresentation
    let dragState: ScreenDragState
    let actions: CardActions
    @Binding var interactingSnapshotId: String?
    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.canvas
            CameraTransform(camera: interaction.camera) {
                ZStack(alignment: .topLeading) {
                    CardsLayer(
                        slots: presentation.layout?.slots ?? [],
                        commentCounts: presentation.commentCounts,
                        tool: tool,
                        workspace: workspace,
                        interaction: interaction,
                        actions: actions,
                        interactingSnapshotId: interactingSnapshotId
                    )
                    MarksLayer(marks: presentation.marks, focusedNoteId: workspace.focusedNoteId,
                               selectedNoteIds: workspace.commentSelection ?? [], camera: interaction.camera)
                    ComponentOutlineLayer(pick: interaction.pick, camera: interaction.camera)
                    DraftLayer(draft: interaction.draft, camera: interaction.camera)
                }
            }
            CanvasInputLayer(interaction: interaction)
            CanvasScrollIndicators(camera: interaction.camera, contentBounds: presentation.layout?.contentBounds)
            ScreenOverlay(
                bubbleInsets: bubbleInsets,
                rows: presentation.layout?.rows ?? [],
                marks: presentation.marks,
                focusedNoteId: workspace.focusedNoteId,
                recordingNoteId: workspace.activeRecording?.noteId,
                workspace: workspace,
                interaction: interaction,
                dragState: dragState,
                interactingSnapshotId: $interactingSnapshotId
            )
            ComponentChip(pick: interaction.pick)
        }
    }
}
#endif
