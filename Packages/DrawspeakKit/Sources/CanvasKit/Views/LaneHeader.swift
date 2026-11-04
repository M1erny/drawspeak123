#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Lane controls scroll at extreme zoom instead of dropping actions.
struct LaneHeader: View {
    let lane: Lane
    let workspace: Workspace
    @Binding var interactingSnapshotId: String?
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CanvasMetrics.spacing) {
                if lane.versions.count > 1 {
                    VersionMenu(lane: lane, workspace: workspace)
                } else {
                    LaneTitle(lane: lane)
                }
                if let snapshot = lane.selected, snapshot.kind == .html {
                    LaneTryButton(snapshot: snapshot, workspace: workspace, interactingSnapshotId: $interactingSnapshotId)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(.primary)
    }
}
#endif
