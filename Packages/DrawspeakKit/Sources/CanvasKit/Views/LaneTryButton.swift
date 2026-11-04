#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

struct LaneTryButton: View {
    let snapshot: Snapshot
    let workspace: Workspace
    @Binding var interactingSnapshotId: String?
    private var isActive: Bool { interactingSnapshotId == snapshot.id }
    var body: some View {
        Button(isActive ? String(localized: "Done", bundle: .module) : String(localized: "Try Prototype", bundle: .module),
               systemImage: isActive ? "xmark" : "hand.tap", action: toggle)
            .labelStyle(.iconOnly)
            .foregroundStyle(.primary)
            .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
            .accessibilityAddTraits(isActive ? .isSelected : [])
            .disabled(!workspace.isSourceAvailable(snapshot))
            .accessibilityShowsLargeContentViewer()
    }
    private func toggle() { interactingSnapshotId = isActive ? nil : snapshot.id }
}
#endif
