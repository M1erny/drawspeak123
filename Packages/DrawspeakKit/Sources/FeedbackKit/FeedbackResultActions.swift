import SwiftUI

/// The way forward after a send that did not fully succeed.
struct FeedbackResultActions: View {
    let model: FeedbackPreviewModel
    let phase: FeedbackResultPhase

    var body: some View {
        switch phase {
        case .unknown:
            Button(action: check) { Label { Text("Check Thread", bundle: .module) } icon: { Image(systemName: "arrow.clockwise") } }
                .disabled(model.busy)
        case .failed:
            Button(action: retry) {
                Label {
                    if model.sentCount > 0 { Text("Send Remaining", bundle: .module) } else { Text("Try Again", bundle: .module) }
                } icon: { Image(systemName: "arrow.clockwise") }
            }
            .disabled(model.busy)
        case .ready:
            Button(action: retry) { Label { Text("Send Again", bundle: .module) } icon: { Image(systemName: "paperplane") } }
                .disabled(model.busy)
        case .working, .sent:
            EmptyView()
        }
    }

    private func check() { Task { await model.reconcile() } }
    private func retry() { Task { await model.retry() } }
}
