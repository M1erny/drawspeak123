import CoreGraphics
import DrawspeakCore

/// A screen row in world space: Now first, then its proposal lanes.
nonisolated struct ScreenRow: Identifiable, Equatable, Sendable {
    /// The screen, with its laid-out origin plus any live drag offset.
    var screen: Screen
    /// The laid-out origin (stored origin pushed below earlier rows), before
    /// the live drag offset. A drag persists `baseOrigin + translation`.
    var baseOrigin: WorldPoint
    var slots: [LaneSlot]

    var id: String { screen.id }
}
