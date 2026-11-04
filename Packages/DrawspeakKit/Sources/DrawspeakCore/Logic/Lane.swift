import Foundation

/// A column of one screen on the canvas: Now or one proposal with its iterations.
public struct Lane: Hashable, Identifiable, Sendable {
    public var key: LaneKey
    public var title: String
    /// Versions in this lane, oldest first. For Now: baseline revisions, then
    /// unpromoted baseline snapshots (see `CanvasLayout.isUnpromotedBaseline`).
    public var versions: [Snapshot]
    public var selected: Snapshot?

    public var id: String { key.description }
}
