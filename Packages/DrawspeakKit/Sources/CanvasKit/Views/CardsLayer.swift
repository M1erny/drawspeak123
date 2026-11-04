#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// All snapshot cards in world space. Reads only the settled camera, so cards
/// change resolution or mount live HTML when a gesture ends, not mid-gesture.
struct CardsLayer: View {
    let slots: [LaneSlot]
    let commentCounts: [String: Int]
    let tool: CanvasTool
    let workspace: Workspace
    let interaction: CanvasInteraction
    let actions: CardActions
    let interactingSnapshotId: String?

    @Environment(\.displayScale) private var displayScale

    /// Below this zoom HTML cards show their capture image only.
    static let liveHTMLMinimumZoom = 0.35

    var body: some View {
        let camera = interaction.camera
        let visible = camera.settledVisibleWorld
        let zoom = camera.settled.zoom
        let bucket = ImageCache.bucket(worldWidth: CanvasLayout.laneWidth, zoom: zoom, displayScale: displayScale)
        ForEach(slots) { slot in
            let snapshot = slot.snapshot
            let isLive = snapshot?.kind == .html && slot.frame.intersects(visible)
                && (snapshot?.id == interactingSnapshotId || zoom >= Self.liveHTMLMinimumZoom || tool == .component || snapshot?.image == nil)
            let count = snapshot.map { commentCounts[$0.id] ?? 0 } ?? 0
            SnapshotCard(
                slot: slot,
                workspace: workspace,
                showsLiveHTML: isLive,
                imageMaxPixel: bucket,
                inspector: isLive ? snapshot.map { interaction.inspectors.inspector(slotId: slot.id, snapshotId: $0.id) } : nil,
                accessibilityText: CanvasLabels.card(lane: slot.lane, screenTitle: slot.screen.title, commentCount: count),
                commentCount: count,
                actions: actions,
                allowsInteraction: snapshot?.id == interactingSnapshotId
            )
        }
    }
}
#endif
