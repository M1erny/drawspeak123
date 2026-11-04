import SwiftUI
import DrawspeakCore

public struct FeedbackButton: View {
    public let workspace: Workspace
    public let action: () -> Void
    public init(workspace: Workspace, action: @escaping () -> Void) {
        self.workspace = workspace
        self.action = action
    }
    public var body: some View {
        let scope = workspace.feedbackScope()
        let count = scope?.count ?? 0
        let pending = scope?.pending.filter { $0.isRecording || $0.isTranscribing }.count ?? 0
        Button(action: action) {
            VStack {
                HStack {
                    Text("Feedback")
                    Text(count, format: .number).monospacedDigit().padding(.horizontal, 8)
                        .background(.quaternary, in: .capsule)
                }
                if pending > 0 { Text("\(pending) in progress").font(.caption) }
            }.frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.glassProminent).tint(count > 0 ? Theme.action : Theme.secondaryInk)
        .disabled(count == 0)
        .accessibilityLabel("Feedback, \(count) comments")
        .accessibilityHint(count == 0 ? "Add text to a comment and finish recording to prepare feedback." : "Review comments, then send or save a draft.")
    }
}
