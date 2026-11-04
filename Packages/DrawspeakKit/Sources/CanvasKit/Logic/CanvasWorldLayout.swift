import CoreGraphics
import DrawspeakCore

/// Places every screen row and lane of a canvas in world space, using the
/// shared `CanvasLayout` metrics so hit testing, drawing and framing agree.
nonisolated struct CanvasWorldLayout: Equatable, Sendable {
    var rows: [ScreenRow]

    init(canvas: ReviewCanvas, drag: ScreenDrag? = nil) {
        rows = canvas.screens.map { screen in
            let baseOrigin = screen.origin
            var screen = screen
            if let drag, drag.screenId == screen.id {
                screen.origin = WorldPoint(x: screen.origin.x + drag.dx, y: screen.origin.y + drag.dy)
            }
            let slots = CanvasLayout.lanes(in: canvas, screen: screen).enumerated().map { index, lane in
                LaneSlot(
                    screen: screen,
                    laneIndex: index,
                    lane: lane,
                    frame: Self.frame(screen: screen, laneIndex: index, snapshot: lane.selected)
                )
            }
            return ScreenRow(screen: screen, baseOrigin: baseOrigin, slots: slots)
        }
    }

    var slots: [LaneSlot] { rows.flatMap(\.slots) }

    /// Union of all card frames, or `nil` for an empty canvas.
    var contentBounds: CGRect? {
        slots.map(\.frame).reduce(nil) { partial, frame in partial?.union(frame) ?? frame }
    }

    /// The topmost card under a world point. Later rows draw above earlier ones.
    func slot(at point: CGPoint) -> LaneSlot? {
        slots.last { $0.frame.contains(point) }
    }

    func slot(id: String) -> LaneSlot? {
        slots.first { $0.id == id }
    }

    /// World frame of a snapshot's card: the lane showing it, or the lane that
    /// holds it as another version (sized for that version).
    func frame(forSnapshot snapshotId: String) -> CGRect? {
        if let slot = slots.first(where: { $0.snapshot?.id == snapshotId }) { return slot.frame }
        for slot in slots {
            guard let version = slot.lane.versions.first(where: { $0.id == snapshotId }) else { continue }
            return Self.frame(screen: slot.screen, laneIndex: slot.laneIndex, snapshot: version)
        }
        return nil
    }

    static func frame(screen: Screen, laneIndex: Int, snapshot: Snapshot?) -> CGRect {
        let frame = CanvasLayout.laneContentFrame(screen: screen, laneIndex: laneIndex, snapshot: snapshot)
        return CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
    }
}
