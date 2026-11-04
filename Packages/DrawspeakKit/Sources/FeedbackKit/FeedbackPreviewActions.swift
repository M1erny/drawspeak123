import SwiftUI
import DrawspeakCore

struct FeedbackPreviewActions: View {
    let model: FeedbackPreviewModel
    var body: some View {
        VStack(spacing: FeedbackLayout.spacing) {
            if let reason = model.sendBlock {
                Text(reason).font(.footnote).foregroundStyle(.secondary)
            }
            Button(action: save) { Text("Save Draft", bundle: .module) }
                .buttonStyle(.bordered)
                .disabled(model.busy || model.selection.isEmpty)
                .frame(minHeight: Theme.minTarget)
        }
        .frame(maxWidth: .infinity).padding()
    }
    private func save() { Task { await model.save() } }
}
