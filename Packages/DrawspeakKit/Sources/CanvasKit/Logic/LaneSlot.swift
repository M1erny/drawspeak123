import CoreGraphics
import DrawspeakCore

/// One lane placed in world space: its selected version and card frame.
nonisolated struct LaneSlot: Identifiable, Equatable, Sendable {
    var screen: Screen
    var laneIndex: Int
    var lane: Lane
    /// World frame of the snapshot card, below the lane header.
    var frame: CGRect

    var id: String { lane.id }
    var snapshot: Snapshot? { lane.selected }
}
