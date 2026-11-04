#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Screen-space chrome that keeps a constant size at every zoom: screen
/// titles, lane headers and pins. Only items near the viewport are built.
struct ScreenOverlay: View {
    let rows: [ScreenRow]
    let marks: [PlacedMark]
    let focusedNoteId: UUID?
    let recordingNoteId: UUID?
    let workspace: Workspace
    let interaction: CanvasInteraction
    let dragState: ScreenDragState
    @Binding var interactingSnapshotId: String?

    @ScaledMetric(relativeTo: .headline) private var headerHeight = 44.0
    @State private var placements = ScreenOverlayPlacements()
    static let gap: CGFloat = 2

    var body: some View {
        let camera = interaction.camera.state

        ZStack(alignment: .topLeading) {
            ForEach(placements.titles) { item in
                ScreenTitleChip(
                    screen: item.row.screen,
                    baseOrigin: item.row.baseOrigin,
                    zoom: camera.zoom,
                    workspace: workspace,
                    dragState: dragState
                )
                .fixedSize()
                .offset(x: item.origin.x, y: item.origin.y)
            }
            ForEach(placements.headers) { item in
                LaneHeader(lane: item.slot.lane, workspace: workspace, interactingSnapshotId: $interactingSnapshotId)
                    .frame(width: max(item.rect.width, 1), height: headerHeight, alignment: .leading)
                    .offset(x: item.rect.minX, y: item.rect.minY - headerHeight - Self.gap)
            }
            ForEach(placements.pins) { item in
                PinButton(
                    ordinal: item.mark.ordinal,
                    label: item.mark.pinLabel,
                    isFocused: item.mark.noteId == focusedNoteId,
                    isRecording: item.mark.noteId == recordingNoteId
                ) {
                    workspace.focusedNoteId = item.mark.noteId
                }
                .offset(x: item.center.x - Theme.minTarget / 2, y: item.center.y - Theme.minTarget / 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: rows, initial: true, updatePlacements)
        .onChange(of: marks, updatePlacements)
        .onChange(of: interaction.camera.state, updatePlacements)
        .onChange(of: interaction.camera.viewSize, updatePlacements)
        .onChange(of: headerHeight, updatePlacements)
    }
    private func updatePlacements() {
        placements.update(rows: rows, marks: marks, camera: interaction.camera.state,
                          viewSize: interaction.camera.viewSize, headerHeight: headerHeight)
    }
}
#endif
