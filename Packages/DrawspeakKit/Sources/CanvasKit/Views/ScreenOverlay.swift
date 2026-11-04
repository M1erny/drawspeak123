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

    static let headerHeight: CGFloat = 44
    static let gap: CGFloat = 2

    var body: some View {
        let camera = interaction.camera.state
        let visible = CGRect(origin: .zero, size: interaction.camera.viewSize).insetBy(dx: -120, dy: -120)
        let headers = rows.flatMap(\.slots).compactMap { slot -> LaneSlotPlacement? in
            let rect = CanvasFraming.worldToScreen(slot.frame, camera: camera)
            let header = CGRect(x: rect.minX, y: rect.minY - Self.headerHeight - Self.gap, width: rect.width, height: Self.headerHeight)
            return header.intersects(visible) ? LaneSlotPlacement(slot: slot, rect: rect) : nil
        }
        let titles = rows.compactMap { row -> ScreenRowPlacement? in
            guard let first = row.slots.first else { return nil }
            let rect = CanvasFraming.worldToScreen(first.frame, camera: camera)
            let origin = CGPoint(x: rect.minX, y: rect.minY - 2 * (Self.headerHeight + Self.gap))
            return visible.contains(origin) ? ScreenRowPlacement(row: row, origin: origin) : nil
        }
        let pins = marks.compactMap { mark -> PinPlacement? in
            let point = CanvasFraming.worldToScreen(mark.anchor, camera: camera)
            return visible.contains(point) ? PinPlacement(mark: mark, center: point) : nil
        }

        ZStack(alignment: .topLeading) {
            ForEach(titles) { item in
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
            ForEach(headers) { item in
                LaneHeader(lane: item.slot.lane, workspace: workspace, interactingSnapshotId: $interactingSnapshotId)
                    .frame(width: max(item.rect.width, 1), height: Self.headerHeight, alignment: .leading)
                    .offset(x: item.rect.minX, y: item.rect.minY - Self.headerHeight - Self.gap)
            }
            ForEach(pins) { item in
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
    }
}
#endif
