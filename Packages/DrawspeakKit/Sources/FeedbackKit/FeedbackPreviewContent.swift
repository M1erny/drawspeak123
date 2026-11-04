import SwiftUI
import DrawspeakCore

struct FeedbackPreviewContent: View {
    @Bindable var model: FeedbackPreviewModel
    let onChooseThread: (() -> Void)?

    var body: some View {
        Group {
            if model.savedCount != nil {
                ContentUnavailableView {
                    Label { Text("Saved as Draft", bundle: .module) } icon: { Image(systemName: "doc.badge.checkmark") }
                }
            } else if model.preparationFailed {
                FeedbackPreparationFailure(model: model)
            } else if model.showsResult, let entry = model.entry {
                FeedbackDeliveryResult(model: model, entry: entry)
            } else {
                List {
                    Section {
                        FeedbackRecipientRow(model: model, onChooseThread: onChooseThread)
                        if model.startsNewThread {
                            FeedbackNewThreadFields(model: model)
                        }
                    } footer: {
                        if model.startsNewThread && model.workspace.canvas(model.canvasId)?.thread != nil {
                            Text("This canvas will continue in the new thread.", bundle: .module)
                        }
                    }
                    if model.pendingCount > 0 {
                        Text("^[\(model.pendingCount) comment](inflect: true) still transcribing", bundle: .module)
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if !model.newNotes.isEmpty {
                        Button(action: model.addNew) { Text("Add ^[\(model.newNotes.count) New Comment](inflect: true)", bundle: .module) }
                    }
                    ForEach(model.snapshotGroups) { group in
                        Section {
                            FeedbackSnapshotGroup(group: group, model: model)
                        } header: { Text(group.title) }
                    }
                    if model.candidates.isEmpty {
                        ContentUnavailableView {
                            Label { Text("Nothing to Send", bundle: .module) } icon: { Image(systemName: "text.bubble") }
                        }
                    }
                }
                .disabled(model.busy)
            }
        }
        .overlay(alignment: .bottom) {
            if !model.preparationFailed, let error = model.error ?? model.workspace.lastSaveError {
                Text(error).font(.footnote).padding().background(.regularMaterial)
            }
        }
    }
}
