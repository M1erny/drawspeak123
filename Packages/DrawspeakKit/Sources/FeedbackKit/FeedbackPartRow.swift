import SwiftUI
import DrawspeakCore

/// One message of a multi-message send with its delivery state.
struct FeedbackPartRow: View {
    let index: Int
    let count: Int
    let part: FeedbackPackage
    let entry: OutboxEntry?

    var body: some View {
        LabeledContent {
            HStack(spacing: FeedbackLayout.rowPadding) {
                switch entry?.state {
                case .sent:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityHidden(true)
                    Text("Sent", bundle: .module)
                case .uploading, .sending:
                    ProgressView()
                    Text(entry?.state.feedbackLabel ?? "")
                case .deliveryUnknown:
                    Image(systemName: "questionmark.circle").foregroundStyle(.orange).accessibilityHidden(true)
                    Text("Not Confirmed", bundle: .module)
                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).accessibilityHidden(true)
                    Text("Failed", bundle: .module)
                case .readyToSend:
                    Text("Ready", bundle: .module)
                case nil:
                    Text("Waiting", bundle: .module)
                }
            }
            .font(.subheadline)
        } label: {
            Text("Message \(index) of \(count)", bundle: .module)
            Text("^[\(part.items.count) comment](inflect: true) · ^[\(FeedbackPackageSplitter.attachmentCount(of: part)) attachment](inflect: true)", bundle: .module)
        }
    }
}
