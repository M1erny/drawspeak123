import SwiftUI
import DrawspeakCore

struct FeedbackPreviewContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: FeedbackPreviewModel
    let onChooseThread: (() -> Void)?

    var body: some View {
        ZStack {
            if model.savedCount != nil {
                ContentUnavailableView {
                    Label { Text("Saved as Draft", bundle: .module) } icon: { Image(systemName: "doc.badge.checkmark") }
                }
                .transition(resultTransition)
            } else if model.preparationFailed {
                FeedbackPreparationFailure(model: model)
                    .transition(resultTransition)
            } else if model.showsResult, let entry = model.entry {
                FeedbackDeliveryResult(model: model, entry: entry)
                    .transition(resultTransition)
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
                    FeedbackDirectiveSection(model: model)
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
        .animation(.easeInOut(duration: reduceMotion ? 0.1 : 0.2), value: model.showsResult)
        .animation(.easeInOut(duration: reduceMotion ? 0.1 : 0.2), value: model.entry?.state)
        .sensoryFeedback(.success, trigger: succeeded) { _, newValue in newValue }
        .sensoryFeedback(.error, trigger: failure) { _, newValue in newValue != nil }
        .overlay(alignment: .bottom) {
            if !model.preparationFailed, let error = model.error ?? model.workspace.lastSaveError {
                Text(error).font(.footnote).padding().background(.regularMaterial)
            }
        }
    }

    private var resultTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8))
    }

    private var succeeded: Bool {
        if model.savedCount != nil { return true }
        if case .sent = model.entry?.state { return true }
        return false
    }

    private var failure: String? {
        if let error = model.error ?? model.workspace.lastSaveError { return error }
        if case .failed(let reason) = model.entry?.state { return reason }
        return nil
    }
}
