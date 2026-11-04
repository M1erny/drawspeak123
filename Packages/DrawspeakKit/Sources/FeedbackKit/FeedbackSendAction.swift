import SwiftUI
import DrawspeakCore

struct FeedbackSendAction: View {
    let model: FeedbackPreviewModel
    let onChooseThread: (() -> Void)?

    var body: some View {
        Button(action: send) {
            HStack {
                if model.busy { ProgressView().tint(.white) }
                Text("Send", bundle: .module)
            }
        }
        .buttonStyle(.glassProminent).tint(Theme.actionFill)
        .disabled(model.busy || model.selection.isEmpty || model.sendBlock != nil ||
            ((model.recipient == nil || model.workspace.threads == nil) && onChooseThread == nil))
        .accessibilityHint(Text(model.sendBlock ?? ""))
    }

    private func send() {
        if model.recipient == nil || model.workspace.threads == nil { onChooseThread?() }
        else { Task { await model.send() } }
    }
}
