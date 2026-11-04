import CoreGraphics
import DrawspeakCore

/// A screen row in world space: Now first, then its proposal lanes.
nonisolated struct ScreenRow: Identifiable, Equatable, Sendable {
    /// The screen, with any live drag offset applied to its origin.
    var screen: Screen
    /// The persisted origin, before the live drag offset.
    var baseOrigin: WorldPoint
    var slots: [LaneSlot]

    var id: String { screen.id }
}
