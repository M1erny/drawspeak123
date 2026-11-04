import Foundation

/// Derives the lanes of a screen and their selected versions.
public enum CanvasLayout {
    public static let laneWidth: Double = 420
    public static let laneSpacing: Double = 64
    public static let rowSpacing: Double = 160
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
            .filter { $0.screenId == screenId && $0.role == .proposal && $0.proposalId == proposalId }
            .sorted { ($0.iteration, $0.capturedAt) < ($1.iteration, $1.capturedAt) }
    }

    public static func proposalIds(in canvas: ReviewCanvas, screen: Screen) -> [String] {
        let present = Set(canvas.snapshots.filter { $0.screenId == screen.id && $0.role == .proposal }.compactMap(\.proposalId))
        let ordered = screen.proposalOrder.filter(present.contains)
        let rest = present.subtracting(ordered).sorted()
        return ordered + rest
    }

    public static func proposalTitle(_ proposalId: String) -> String {
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
        lanes.append(Lane(key: nowKey, title: "Now", versions: nowVersions, selected: nowSelected))
        for proposalId in proposalIds(in: canvas, screen: screen) {
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

    /// The origin for a new screen row below every existing row.
    public static func nextScreenOrigin(in canvas: ReviewCanvas) -> WorldPoint {
        var maxY = 0.0
        for screen in canvas.screens {
            let lanes = lanes(in: canvas, screen: screen)
            let tallest = lanes.map { contentHeight(for: $0.selected) }.max() ?? laneWidth
            maxY = max(maxY, screen.origin.y + headerHeight + tallest + rowSpacing)
        }
        return WorldPoint(x: 0, y: maxY)
    }

    /// World-space frame of a lane's content (below the header).
    public static func laneContentFrame(screen: Screen, laneIndex: Int, snapshot: Snapshot?) -> (x: Double, y: Double, width: Double, height: Double) {
        let x = screen.origin.x + Double(laneIndex) * (laneWidth + laneSpacing)
        let y = screen.origin.y + headerHeight
        return (x, y, laneWidth, contentHeight(for: snapshot))
    }
}
