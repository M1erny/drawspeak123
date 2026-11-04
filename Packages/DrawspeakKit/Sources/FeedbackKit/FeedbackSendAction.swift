import SwiftUI
import DrawspeakCore

struct FeedbackSendAction: View {
    let model: FeedbackPreviewModel
    let onChooseThread: (() -> Void)?

    var body: some View {
        Button(action: send) {
            HStack {
                if model.busy { ProgressView().tint(.white) }
                Text("Send", bundle: .module).foregroundStyle(.white)
            }
        }
        .buttonStyle(.glassProminent).tint(Theme.actionFill)
        .disabled(model.busy || model.selection.isEmpty || model.sendBlock != nil || !canSend)
        .accessibilityHint(Text(model.sendBlock ?? ""))
    }

    private var startsNewThread: Bool { model.startsNewThread }

    private var canSend: Bool {
        if startsNewThread { return model.newThreadReady }
        return (model.recipient != nil && model.workspace.threads != nil) || onChooseThread != nil
    }

    private func send() {
        if !startsNewThread && (model.recipient == nil || model.workspace.threads == nil) { onChooseThread?() }
        else { Task { await model.send() } }
    }
}
