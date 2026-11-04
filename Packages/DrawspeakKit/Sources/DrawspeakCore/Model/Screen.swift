import Foundation

/// A logical screen on a canvas. Its versions are lanes placed side by side:
/// Now first, then one lane per proposal.
public struct Screen: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    /// Top-left corner of the screen's row in world coordinates (points).
    public var origin: WorldPoint
    /// Proposal ids in display order.
    public var proposalOrder: [String]

    public init(id: String, title: String, origin: WorldPoint, proposalOrder: [String] = []) {
        self.id = id
        self.title = title
        self.origin = origin
        self.proposalOrder = proposalOrder
    }
}

/// A point in canvas world coordinates, in points at zoom 1.
public struct WorldPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
