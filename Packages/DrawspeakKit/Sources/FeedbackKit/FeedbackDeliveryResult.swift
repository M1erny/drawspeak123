import SwiftUI
import DrawspeakCore

struct FeedbackDeliveryResult: View {
    let model: FeedbackPreviewModel
    let entry: OutboxEntry
    var body: some View {
        ScrollView {
            VStack(spacing: FeedbackLayout.sectionSpacing) {
                Text(title)
                    .font(.title2).accessibilityAddTraits(.isHeader)
                switch entry.state {
                case .sent:
                    if let receipt = entry.receipt { Text(receipt.acknowledgedAt, format: .dateTime.hour().minute()).foregroundStyle(.secondary) }
                case .uploading(let done, let total): ProgressView(value: Double(done), total: Double(max(total, 1)))
                case .sending: ProgressView()
                case .deliveryUnknown:
                    Button(action: check) { Text("Check Thread", bundle: .module) }.disabled(model.busy)
                case .failed:
                    Button(action: retry) { Text("Try Again", bundle: .module) }.disabled(model.busy)
                case .readyToSend:
                    Text("May send twice.", bundle: .module).font(.footnote)
                    Button(action: retry) { Text("Send", bundle: .module) }
                        .buttonStyle(.glassProminent).tint(Theme.actionFill).disabled(model.busy)
                }
                if let notice = model.reconciliationNotice { Text(notice).font(.subheadline) }
            }.frame(maxWidth: .infinity).padding()
        }
    }
    private var title: String {
        switch entry.state {
        case .deliveryUnknown: String(localized: "Delivery Not Confirmed", bundle: .module)
        case .sent where !entry.thread.threadTitle.isEmpty: String(localized: "Sent to \(entry.thread.threadTitle)", bundle: .module)
        default: entry.state.feedbackLabel
        }
    }
    private func check() { Task { await model.reconcile() } }
    private func retry() { Task { await model.retry() } }
}
