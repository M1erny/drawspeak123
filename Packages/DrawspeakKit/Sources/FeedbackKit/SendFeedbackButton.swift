import SwiftUI
import DrawspeakCore

public struct SendFeedbackButton: View {
    public let workspace: Workspace
    public let action: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var count = 0

    public init(workspace: Workspace, action: @escaping () -> Void) {
        self.workspace = workspace
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(count > 0 ? "Send \(count)" : "Send", bundle: .module)
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(reduceMotion ? .identity : .numericText())
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: count)
        .buttonStyle(.glassProminent)
        .disabled(count == 0)
        .frame(minHeight: Theme.minTarget)
        .accessibilityValue(Text("^[\(count) comment](inflect: true)", bundle: .module))
        .accessibilityHint(Text("Reviews comments before sending.", bundle: .module))
        .task(id: workspace.currentCanvas) { refreshCount() }
        .onChange(of: scenePhase) { if scenePhase == .active { refreshCount() } }
    }

    private func refreshCount() { count = workspace.feedbackScope()?.count ?? 0 }
}
