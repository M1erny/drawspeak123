import SwiftUI
import DrawspeakCore

struct FeedbackDeliveryResult: View {
    let model: FeedbackPreviewModel
    let entry: OutboxEntry
    let onClose: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry.state.feedbackLabel).font(.title2)
            switch entry.state {
            case .sent:
                Text("Sent to \(entry.thread.displayName) · \(entry.items.count) comments · \(entry.receipt?.acknowledgedAt.formatted(date: .omitted, time: .shortened) ?? "")")
                Text("Delivered to T3 Code. The agent's work status is shown separately.").font(.subheadline)
                if let status = entry.agentStatus { Text("Agent: \(status)") }
            case .uploading(let done, let total): ProgressView(value: Double(done), total: Double(max(total, 1)))
            case .sending: ProgressView("Sending…")
            case .deliveryUnknown:
                Text("We don't know if the message arrived")
                Button("Check Thread") { Task { await model.reconcile() } }.disabled(model.busy)
            case .failed(let reason):
                Text(reason).foregroundStyle(.red)
                Button("Try Again") { Task { await model.retry() } }.disabled(model.busy)
            case .readyToSend:
                Button("Send") { Task { await model.retry() } }.buttonStyle(.glassProminent).tint(Theme.action).disabled(model.busy)
            }
            if let notice = model.reconciliationNotice { Text(notice).font(.subheadline) }
            Button("Back to Canvas", action: onClose).disabled(model.busy).frame(minHeight: 44)
        }.controlSize(.large)
    }
}
