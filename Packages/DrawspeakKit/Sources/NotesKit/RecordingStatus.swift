import SwiftUI
import DrawspeakCore

struct RecordingStatus: View {
    let workspace: Workspace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let elapsed = NotesPresentation.duration(workspace.voice?.elapsed ?? 0)
            HStack {
                Circle().fill(.red).frame(width: NotesMetrics.recordingDot, height: NotesMetrics.recordingDot)
                    .opacity(reduceMotion ? 1 : 0.65 + 0.35 * sin(context.date.timeIntervalSinceReferenceDate * 4))
                ProgressView(value: min(1, max(0, workspace.voice?.level ?? 0)))
                    .tint(.red).frame(width: NotesMetrics.levelWidth)
                    .accessibilityHidden(true)
                Text(elapsed).monospacedDigit()
            }
            .font(.caption)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Recording, \(elapsed)", bundle: .module))
        }
    }
}
