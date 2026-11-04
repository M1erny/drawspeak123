import SwiftUI

struct FeedbackRecipientRow: View {
    let model: FeedbackPreviewModel
    let onChooseThread: (() -> Void)?

    var body: some View {
        LabeledContent {
            Menu {
                Button(action: chooseThread) {
                    Text("Change Thread…", bundle: .module)
                }
                .disabled(onChooseThread == nil)
                Button(action: model.chooseNewThread) { Text("New Thread", bundle: .module) }
                    .disabled(!model.canStartNewThread)
            } label: {
                if model.startsNewThread { Text("New Thread", bundle: .module) }
                else if let thread = model.recipient { Text(thread.displayName) }
                else { Text("Choose Thread…", bundle: .module) }
            }
            .disabled(model.busy)
        } label: { Text("To", bundle: .module) }
    }

    private func chooseThread() {
        model.startsNewThread = false
        onChooseThread?()
    }
}
