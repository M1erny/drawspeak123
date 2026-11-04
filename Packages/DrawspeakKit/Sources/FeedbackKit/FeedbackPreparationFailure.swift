import SwiftUI

struct FeedbackPreparationFailure: View {
    let model: FeedbackPreviewModel
    var body: some View {
        ContentUnavailableView {
            Label { Text("Failed", bundle: .module) } icon: { Image(systemName: "exclamationmark.circle") }
        } description: {
            if let error = model.error { Text(error) }
        } actions: {
            Button(action: retry) { Text("Try Again", bundle: .module) }.disabled(model.busy)
        }
    }
    private func retry() { Task { await model.send() } }
}
