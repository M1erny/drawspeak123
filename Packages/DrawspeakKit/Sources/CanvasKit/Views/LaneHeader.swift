#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// The constant-size header above a lane: its title and version menu. Narrow
/// lanes at low zoom fall back to the menu, then to the title alone.
struct LaneHeader: View {
    let lane: Lane
    let workspace: Workspace
    @Binding var interactingSnapshotId: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                if !lane.key.isNow || lane.versions.count != 1 { title }
                VersionMenu(lane: lane, workspace: workspace)
                tryButton
            }
            HStack { VersionMenu(lane: lane, workspace: workspace); tryButton }
            HStack { title; tryButton }
            title
            Color.clear
                .frame(width: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var tryButton: some View {
        if let snapshot = lane.selected, snapshot.kind == .html {
            Button(interactingSnapshotId == snapshot.id ? "Done" : "Try", systemImage: "hand.tap") {
                interactingSnapshotId = interactingSnapshotId == snapshot.id ? nil : snapshot.id
            }
            .disabled(!workspace.isSourceAvailable(snapshot))
            .font(.subheadline)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityHint("Try this isolated offline prototype. Changes are not saved.")
        }
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
