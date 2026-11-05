import SwiftUI

struct FeedbackPreparationFailure: View {
    let model: FeedbackPreviewModel
    var body: some View {
        ContentUnavailableView {
            Label { Text("Couldn't Prepare Feedback", bundle: .module) } icon: { Image(systemName: "exclamationmark.triangle") }
        } description: {
            if let error = model.error { Text(error) }
            Text("Nothing was sent.", bundle: .module)
        } actions: {
            Button(action: retry) { Text("Try Again", bundle: .module) }
                .buttonStyle(.bordered)
                .disabled(model.busy)
            Button(action: model.backToList) { Text("Back to Comments", bundle: .module) }
                .disabled(model.busy)
        }
    }
    private func retry() { Task { await model.retry() } }
}
