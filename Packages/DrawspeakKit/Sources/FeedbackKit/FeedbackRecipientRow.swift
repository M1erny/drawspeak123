import SwiftUI

struct FeedbackRecipientRow: View {
    let model: FeedbackPreviewModel
    let onChooseThread: (() -> Void)?
    var body: some View {
        LabeledContent {
            if let thread = model.recipient { Text(thread.displayName) }
            else {
                Button(action: chooseThread) { Text("Choose Thread…", bundle: .module) }
                    .disabled(onChooseThread == nil || model.busy)
            }
        } label: { Text("To", bundle: .module) }
    }
    private func chooseThread() { onChooseThread?() }
}
