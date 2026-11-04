#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// The constant-size header above a lane: its title and version menu. Narrow
/// lanes at low zoom fall back to the menu, then to the title alone.
struct LaneHeader: View {
    let lane: Lane
    let workspace: Workspace

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                title
                VersionMenu(lane: lane, workspace: workspace)
            }
            VersionMenu(lane: lane, workspace: workspace)
            title
            Color.clear
                .frame(width: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: some View {
        Text(lane.title)
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.leading, 4)
    }
}
#endif
