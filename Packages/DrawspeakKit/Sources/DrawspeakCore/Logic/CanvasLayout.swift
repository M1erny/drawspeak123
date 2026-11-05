import Foundation

/// Derives the lanes of a screen and their selected versions.
public enum CanvasLayout {
    public static let laneWidth: Double = 420
    public static let laneSpacing: Double = 64
    public static let rowSpacing: Double = 240
    public static let headerHeight: Double = 56

    /// Snapshot ids of every baseline revision of a screen, oldest first.
    public static func baselineSnapshots(in canvas: ReviewCanvas, screenId: String) -> [Snapshot] {
        canvas.baselineRevisions
            .filter { $0.screenId == screenId }
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { revision in canvas.snapshots.first { $0.id == revision.snapshotId } }
    }

    /// Baseline snapshots of a screen that were stored (for example by Pull) but
    /// never made Now, oldest first. They become Now only through `promoteToNow`.
    public static func unpromotedBaselineSnapshots(in canvas: ReviewCanvas, screenId: String) -> [Snapshot] {
        let revised = Set(canvas.baselineRevisions.map(\.snapshotId))
        return canvas.snapshots
            .filter { $0.screenId == screenId && $0.role == .baseline && !revised.contains($0.id) }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    /// True for a baseline snapshot that is not, and never was, a Now revision.
    public static func isUnpromotedBaseline(_ snapshot: Snapshot, in canvas: ReviewCanvas) -> Bool {
        snapshot.role == .baseline && !canvas.baselineRevisions.contains { $0.snapshotId == snapshot.id }
    }

    /// Now for a screen: the latest explicit baseline revision.
    public static func now(in canvas: ReviewCanvas, screenId: String) -> Snapshot? {
        baselineSnapshots(in: canvas, screenId: screenId).last
    }

    public static func proposalIterations(in canvas: ReviewCanvas, screenId: String, proposalId: String) -> [Snapshot] {
        canvas.snapshots
            .filter { $0.screenId == screenId && $0.role == .proposal && $0.laneId == proposalId }
            .sorted { ($0.iteration, $0.capturedAt) < ($1.iteration, $1.capturedAt) }
    }

    /// The column id of a follow-up kept next to its earlier iteration: `a` → `a-2`.
    public static func followUpLaneId(proposalId: String, iteration: Int) -> String { "\(proposalId)-\(iteration)" }

    /// The proposal a column belongs to: `a-2` → `a`.
    public static func baseProposalId(_ laneId: String) -> String {
        guard let dash = laneId.lastIndex(of: "-"), Int(laneId[laneId.index(after: dash)...]) != nil else { return laneId }
        return String(laneId[..<dash])
    }

    public static func proposalIds(in canvas: ReviewCanvas, screen: Screen) -> [String] {
        let present = Set(canvas.snapshots.filter { $0.screenId == screen.id && $0.role == .proposal }.compactMap(\.laneId))
        let ordered = screen.proposalOrder.filter(present.contains)
        let rest = present.subtracting(ordered).sorted()
        return ordered + rest
    }

    public static func proposalTitle(_ proposalId: String) -> String {
        let base = baseProposalId(proposalId)
        if base != proposalId, let iteration = proposalId.split(separator: "-").last {
            return "\(proposalTitle(base)) · \(iteration)"
        }
        let trimmed = proposalId.trimmingCharacters(in: .whitespaces)
        if trimmed.count <= 2 { return "Proposal \(trimmed.uppercased())" }
        return "Proposal \(trimmed)"
    }

    public static func lanes(in canvas: ReviewCanvas, screen: Screen) -> [Lane] {
        var lanes: [Lane] = []
        let baseline = baselineSnapshots(in: canvas, screenId: screen.id)
        // Revisions first, then pulled reference versions waiting for Promote to Now.
        let nowVersions = baseline + unpromotedBaselineSnapshots(in: canvas, screenId: screen.id)
        let nowKey = LaneKey(screenId: screen.id, proposalId: nil)
        let nowSelected = canvas.laneSelections[nowKey.description].flatMap { id in nowVersions.first { $0.id == id } }
            ?? baseline.last ?? nowVersions.last
        let proposals = proposalIds(in: canvas, screen: screen)
        // An empty Now lane only stands in for a screen with no versions at all;
        // proposals start at the first lane until something is promoted to Now.
        if !nowVersions.isEmpty || proposals.isEmpty {
            lanes.append(Lane(key: nowKey, title: "Now", versions: nowVersions, selected: nowSelected))
        }
        for proposalId in proposals {
            let key = LaneKey(screenId: screen.id, proposalId: proposalId)
            let versions = proposalIterations(in: canvas, screenId: screen.id, proposalId: proposalId)
            let selected = canvas.laneSelections[key.description].flatMap { id in versions.first { $0.id == id } } ?? versions.last
            lanes.append(Lane(key: key, title: proposalTitle(proposalId), versions: versions, selected: selected))
        }
        return lanes
    }

    /// World-space height of a snapshot card for the fixed lane width.
    public static func contentHeight(for snapshot: Snapshot?) -> Double {
        guard let snapshot else { return laneWidth * 0.75 }
        return laneWidth / snapshot.aspectRatio
    }

    /// World-space width of a row with `laneCount` lanes.
    public static func rowWidth(laneCount: Int) -> Double {
        let count = Double(max(laneCount, 1))
        return count * laneWidth + (count - 1) * laneSpacing
    }

    /// World-space height of a row: the header plus its tallest card.
    public static func rowHeight(lanes: [Lane]) -> Double {
        headerHeight + (lanes.map { contentHeight(for: $0.selected) }.max() ?? laneWidth * 0.75)
    }

    /// Where every screen row is drawn. A stored origin is the row's preferred
    /// position; rows are taken top to bottom (by stored y, then canvas order)
    /// and each is pushed below every earlier row it overlaps horizontally, so
    /// cards whose height is known only after capture never cover the next row.
    public static func screenOrigins(in canvas: ReviewCanvas) -> [String: WorldPoint] {
        let order = canvas.screens.enumerated().sorted { lhs, rhs in
            (lhs.element.origin.y, lhs.offset) < (rhs.element.origin.y, rhs.offset)
        }
        var placed: [(minX: Double, maxX: Double, bottom: Double)] = []
        var origins: [String: WorldPoint] = [:]
        for (_, screen) in order {
            let lanes = lanes(in: canvas, screen: screen)
            let minX = screen.origin.x
            let maxX = minX + rowWidth(laneCount: lanes.count)
            var y = screen.origin.y
            for row in placed where row.minX < maxX && minX < row.maxX {
                y = max(y, row.bottom + rowSpacing)
            }
            origins[screen.id] = WorldPoint(x: minX, y: y)
            placed.append((minX, maxX, y + rowHeight(lanes: lanes)))
        }
        return origins
    }

    /// The origin for a new screen row below every existing row.
    public static func nextScreenOrigin(in canvas: ReviewCanvas) -> WorldPoint {
        let origins = screenOrigins(in: canvas)
        var maxY = 0.0
        for screen in canvas.screens {
            let y = origins[screen.id]?.y ?? screen.origin.y
            maxY = max(maxY, y + rowHeight(lanes: lanes(in: canvas, screen: screen)) + rowSpacing)
        }
        return WorldPoint(x: 0, y: maxY)
    }

    /// World-space frame of a lane's content (below the header). `screen.origin`
    /// must be the laid-out origin (`screenOrigins`), not the stored one.
    public static func laneContentFrame(screen: Screen, laneIndex: Int, snapshot: Snapshot?) -> (x: Double, y: Double, width: Double, height: Double) {
        let x = screen.origin.x + Double(laneIndex) * (laneWidth + laneSpacing)
        let y = screen.origin.y + headerHeight
        return (x, y, laneWidth, contentHeight(for: snapshot))
    }
}
