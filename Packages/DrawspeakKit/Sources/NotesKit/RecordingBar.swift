import SwiftUI
import DrawspeakCore

@available(*, deprecated, message: "Use CommentsInspector")
public struct RecordingBar: View {
    private let workspace: Workspace
    public init(workspace: Workspace) { self.workspace = workspace }
    public var body: some View {
        if workspace.activeRecording != nil {
            CompactRecordingRow(workspace: workspace)
        }
    }
}
