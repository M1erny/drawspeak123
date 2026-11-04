import SwiftUI
import DrawspeakCore

/// What the send contains and how it travels: counts, messages and attachment kinds.
struct FeedbackSummaryRow: View {
    let model: FeedbackPreviewModel

    var body: some View {
        let comments = model.selected.count
        let screens = Set(model.selected.map(\.snapshotId)).count
        LabeledContent {
            Button(action: toggleAll) {
                if allSelected { Text("Deselect All", bundle: .module) } else { Text("Select All", bundle: .module) }
            }
            .buttonStyle(.borderless)
        } label: {
            Text("^[\(comments) comment](inflect: true) on ^[\(screens) screen](inflect: true)", bundle: .module)
            if comments > 0 {
                if model.messageCount > 1 {
                    Text("Sends as \(model.messageCount) messages with \(model.attachmentCount) attachments. T3 Code accepts up to \(FeedbackPackageSplitter.maxAttachmentsPerMessage) per message.", bundle: .module)
                } else {
                    Text("Annotated screenshots, HTML sources and a JSON manifest in one message.", bundle: .module)
                }
            }
        }
    }

    private var allSelected: Bool { model.isSelected(all: model.candidates) }
    private func toggleAll() { model.setSelection(!allSelected, for: model.candidates) }
}
