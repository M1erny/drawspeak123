import SwiftUI
import DrawspeakCore

/// The bottom bar: why Send is unavailable, the selection count and Save Draft.
struct FeedbackPreviewActions: View {
    let model: FeedbackPreviewModel
    var body: some View {
        VStack(spacing: FeedbackLayout.rowPadding) {
            if let reason = model.sendBlock {
                Label { Text(reason) } icon: { Image(systemName: "exclamationmark.circle") }
                    .font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Text("\(model.selection.count) of \(model.candidates.count) selected", bundle: .module)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Button(action: save) { Text("Save Draft", bundle: .module) }
                    .buttonStyle(.bordered)
                    .disabled(model.busy || model.selection.isEmpty)
                    .frame(minHeight: Theme.minTarget)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, FeedbackLayout.rowPadding)
    }
    private func save() { Task { await model.save() } }
}
