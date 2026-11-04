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
            HStack {
                Text("Feedback")
                Text(count, format: .number).monospacedDigit().padding(.horizontal, 8)
                    .background(.quaternary, in: .capsule)
                if pending > 0 {
                    Label("\(pending)", systemImage: "waveform")
                        .font(.caption).padding(.horizontal, 6)
                        .background(.quaternary, in: .capsule)
                }
            }.frame(minWidth: 44)
        }
        .buttonStyle(.borderedProminent).tint(Theme.actionFill)
        .foregroundStyle(.white)
        .controlSize(.large)
        .frame(height: 44)
        .disabled(count == 0)
        .accessibilityLabel("Feedback")
        .accessibilityValue(Text("^[\(count) ready comment](inflect: true), \(pending) in progress"))
        .accessibilityHint(count == 0 ? "Add text to a comment and finish recording to prepare feedback." : "Review comments, then send or save a draft.")
    }
}
