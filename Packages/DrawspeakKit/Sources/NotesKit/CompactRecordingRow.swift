import SwiftUI
import DrawspeakCore

struct CompactRecordingRow: View {
    let workspace: Workspace
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                RecordingStatus(workspace: workspace)
                RecordingActions(workspace: workspace)
            }
            VStack(alignment: .leading) {
                RecordingStatus(workspace: workspace)
                RecordingActions(workspace: workspace)
            }
        }
    }
}
