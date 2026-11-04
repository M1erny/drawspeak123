import SwiftUI
import DrawspeakCore

struct RecordingStatus: View {
    let workspace: Workspace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let elapsed = NotesPresentation.duration(workspace.voice?.elapsed ?? 0)
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .nonRepeating, isActive: !reduceMotion)
                    .accessibilityHidden(true)
                ProgressView(value: min(1, max(0, workspace.voice?.level ?? 0)))
                    .tint(.red).frame(width: NotesMetrics.levelWidth)
                    .accessibilityHidden(true)
                Text(elapsed).monospacedDigit()
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: elapsed)
            }
            .font(.caption)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Recording, \(elapsed)", bundle: .module))
        }
    }
}
