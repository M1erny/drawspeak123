import DrawspeakCore
import Observation

@Observable
final class CanvasPresentation {
    private(set) var layout: CanvasWorldLayout?
    private(set) var marks: [PlacedMark] = []
    private(set) var commentCounts: [String: Int] = [:]
    private var notesBySnapshot: [String: [Note]] = [:]

    func update(canvas: ReviewCanvas?, drag: ScreenDrag?) {
        notesBySnapshot = Dictionary(grouping: canvas?.notes ?? [], by: \.snapshotId)
            .mapValues { $0.sorted { $0.ordinal < $1.ordinal } }
        commentCounts = notesBySnapshot.mapValues(\.count)
        move(canvas: canvas, drag: drag)
    }
    func move(canvas: ReviewCanvas?, drag: ScreenDrag?) {
        layout = canvas.map { CanvasWorldLayout(canvas: $0, drag: drag) }
        marks = layout.map { PlacedMark.marks(in: $0, notesBySnapshot: notesBySnapshot) } ?? []
    }
}
