import SwiftUI
import DrawspeakCore

public struct AddRegionSheet: View {
    private let workspace: Workspace
    private let onDone: () -> Void
    @State private var snapshotId: String

    public init(workspace: Workspace, initialSnapshotId: String? = nil, onDone: @escaping () -> Void) {
        self.workspace = workspace
        self.onDone = onDone
        _snapshotId = State(initialValue: initialSnapshotId ?? workspace.currentCanvas?.snapshots.first?.id ?? "")
    }

    public var body: some View {
        AddRegionContent(workspace: workspace, snapshotId: $snapshotId, onDone: onDone)
            .presentationSizing(.form)
    }
}

#Preview { AddRegionSheet(workspace: NotesPreview.workspace(), onDone: {}) }
