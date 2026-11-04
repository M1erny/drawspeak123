import Foundation

/// A screen row being dragged by its title, in world units. It is applied to
/// the layout live and persisted with `moveScreen` when the drag ends.
nonisolated struct ScreenDrag: Equatable, Sendable {
    var screenId: String
    var dx: Double
    var dy: Double
}
