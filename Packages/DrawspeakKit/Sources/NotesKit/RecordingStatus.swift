import SwiftUI
import DrawspeakCore

struct RecordingStatus: View {
    let workspace: Workspace
    let number: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let elapsed = NotesPresentation.duration(workspace.voice?.elapsed ?? 0)
            HStack(spacing: 8) {
                Circle().fill(.red).frame(width: 10, height: 10)
                    .opacity(reduceMotion ? 1 : 0.65 + 0.35 * sin(context.date.timeIntervalSinceReferenceDate * 4))
                Text("REC").font(.caption.bold())
                Text("Comment \(number)").font(.subheadline)
                Text(elapsed).monospacedDigit().font(.subheadline)
                ProgressView(value: min(1, max(0, workspace.voice?.level ?? 0)))
                    .tint(Theme.annotation).frame(width: 36)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Recording comment \(number), \(elapsed)")
        }
    }
}

#Preview { RecordingStatus(workspace: NotesPreview.workspace(), number: 3) }
