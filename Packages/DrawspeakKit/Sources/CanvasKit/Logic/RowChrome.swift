import CoreGraphics

/// Which constant-size screen chrome fits above a row's cards: the lane
/// headers and, above them, the screen title. At low zoom the world gap
/// between rows is thinner than the chrome, so lines that would cover the
/// previous row's cards are left out (headers first).
nonisolated struct RowChrome: Equatable, Sendable {
    var showsHeaders: Bool
    var showsTitle: Bool
    /// Screen lines between the cards' top edge and the title's top edge.
    var titleLines: Int

    /// Free world-space height above each row's cards, up to the nearest card
    /// of a horizontally overlapping row above it; `.infinity` when none.
    static func clearances(rows: [ScreenRow]) -> [String: CGFloat] {
        let extents = rows.compactMap { row -> (id: String, frame: CGRect)? in
            guard let first = row.slots.first?.frame else { return nil }
            return (row.id, row.slots.dropFirst().reduce(first) { $0.union($1.frame) })
        }
        var result: [String: CGFloat] = [:]
        for row in extents {
            var clearance = CGFloat.infinity
            for other in extents where other.id != row.id
                && other.frame.minY < row.frame.minY
                && other.frame.minX < row.frame.maxX && row.frame.minX < other.frame.maxX {
                clearance = min(clearance, max(0, row.frame.minY - other.frame.maxY))
            }
            result[row.id] = clearance
        }
        return result
    }

    /// `clearance` in world points, `line` is one chrome line in screen points.
    init(clearance: CGFloat, zoom: Double, line: CGFloat) {
        let space = clearance == .infinity ? .infinity : clearance * CGFloat(max(zoom, 0))
        showsHeaders = space >= 2 * line
        showsTitle = space >= line
        titleLines = showsHeaders ? 2 : 1
    }
}
