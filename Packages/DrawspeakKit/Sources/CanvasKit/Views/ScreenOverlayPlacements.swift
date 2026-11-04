#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

@Observable
final class ScreenOverlayPlacements {
    private(set) var headers: [LaneSlotPlacement] = []
    private(set) var titles: [ScreenRowPlacement] = []
    private(set) var pins: [PinPlacement] = []
    private var sourceRows: [ScreenRow] = []
    private var slots: [LaneSlot] = []
    func update(rows: [ScreenRow], marks: [PlacedMark], camera: CameraState, viewSize: CGSize, headerHeight: Double) {
        if sourceRows != rows {
            sourceRows = rows
            slots = rows.flatMap(\.slots)
        }
        let visible = CGRect(origin: .zero, size: viewSize).insetBy(dx: -120, dy: -120)
        headers = slots.compactMap { slot -> LaneSlotPlacement? in
            let rect = CanvasFraming.worldToScreen(slot.frame, camera: camera)
            let header = CGRect(x: rect.minX, y: rect.minY - headerHeight - 2, width: rect.width, height: headerHeight)
            return header.intersects(visible) ? LaneSlotPlacement(slot: slot, rect: rect) : nil
        }
        titles = rows.compactMap { row -> ScreenRowPlacement? in
            guard let first = row.slots.first else { return nil }
            let rect = CanvasFraming.worldToScreen(first.frame, camera: camera)
            let origin = CGPoint(x: rect.minX, y: rect.minY - 2 * (headerHeight + 2))
            return visible.contains(origin) ? ScreenRowPlacement(row: row, origin: origin) : nil
        }
        pins = marks.compactMap { mark -> PinPlacement? in
            let point = CanvasFraming.worldToScreen(mark.anchor, camera: camera)
            return visible.contains(point) ? PinPlacement(mark: mark, center: point) : nil
        }

    }
}
#endif
