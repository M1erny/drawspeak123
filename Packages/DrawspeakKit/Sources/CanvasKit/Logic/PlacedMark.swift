import CoreGraphics
import DrawspeakCore
import Foundation

/// A note's mark placed on the card that shows its snapshot.
nonisolated struct PlacedMark: Identifiable, Equatable, Sendable {
    var slotId: String
    var noteId: UUID
    var ordinal: Int
    var shape: AnnotationShape
    /// World frame of the card the mark is drawn on.
    var frame: CGRect
    var pinLabel: String

    var id: String { "\(slotId)#\(noteId.uuidString)" }

    /// World position of the pin: the top-left corner of the mark's bounds.
    var anchor: CGPoint {
        let bounds = shape.bounds.clamped()
        return SnapshotSpace.world(NPoint(x: bounds.x, y: bounds.y), in: frame)
    }

    /// Marks of every note whose snapshot is the selected version of a lane.
    /// Notes on other versions stay with their own version and are not drawn.
    static func marks(in layout: CanvasWorldLayout, notes: [Note]) -> [PlacedMark] {
        let grouped = Dictionary(grouping: notes, by: \.snapshotId).mapValues { $0.sorted { $0.ordinal < $1.ordinal } }
        return marks(in: layout, notesBySnapshot: grouped)
    }

    static func marks(in layout: CanvasWorldLayout, notesBySnapshot: [String: [Note]]) -> [PlacedMark] {
        var marks: [PlacedMark] = []
        for slot in layout.slots {
            guard let snapshotId = slot.snapshot?.id, let notes = notesBySnapshot[snapshotId] else { continue }
            for note in notes {
                marks.append(PlacedMark(
                    slotId: slot.id,
                    noteId: note.id,
                    ordinal: note.ordinal,
                    shape: note.shape,
                    frame: slot.frame,
                    pinLabel: CanvasLabels.pin(ordinal: note.ordinal, text: note.text, shape: note.shape)
                ))
            }
        }
        return marks
    }
}
