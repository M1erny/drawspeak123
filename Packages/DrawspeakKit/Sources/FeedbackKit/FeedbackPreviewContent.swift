import SwiftUI
import DrawspeakCore

struct FeedbackPreviewContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: FeedbackPreviewModel
    let onChooseThread: (() -> Void)?

    var body: some View {
        ZStack {
            if let saved = model.savedCount {
                ContentUnavailableView {
                    Label { Text("Saved as Draft", bundle: .module) } icon: { Image(systemName: "doc.badge.checkmark").accessibilityHidden(true) }
                } description: {
                    Text("^[\(saved) comment](inflect: true) saved on this iPad. Find them in Drafts and Sent.", bundle: .module)
                }
                .transition(resultTransition)
            } else if model.preparationFailed {
                FeedbackPreparationFailure(model: model)
                    .transition(resultTransition)
            } else if model.showsResult {
                FeedbackDeliveryResult(model: model)
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
                    if !model.candidates.isEmpty {
                        Section {
                            FeedbackSummaryRow(model: model)
                            if model.pendingCount > 0 {
                                Label {
                                    Text("^[\(model.pendingCount) comment](inflect: true) still transcribing", bundle: .module)
                                } icon: { Image(systemName: "waveform") }
                                .foregroundStyle(.secondary)
                            }
                            if !model.newNotes.isEmpty {
                                Button(action: model.addNew) {
                                    Label { Text("Add ^[\(model.newNotes.count) New Comment](inflect: true)", bundle: .module) } icon: { Image(systemName: "plus.circle") }
                                }
                            }
                        }
                    }
                    ForEach(model.snapshotGroups) { group in
                        Section {
                            FeedbackSnapshotGroup(group: group, model: model)
                        } header: {
                            FeedbackGroupHeader(group: group, model: model)
                        }
                    }
                }
                .overlay {
                    if model.candidates.isEmpty {
                        ContentUnavailableView {
                            Label { Text("Nothing to Send", bundle: .module) } icon: { Image(systemName: "text.bubble") }
                        } description: {
                            Text("Draw on a screen and describe the change. Ready comments appear here.", bundle: .module)
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
            if !model.showsResult, let error = model.error ?? model.workspace.lastSaveError {
                Text(error).font(.footnote).padding().background(.regularMaterial, in: .rect(cornerRadius: Theme.cardCornerRadius)).padding()
            }
        }
    }

    private var resultTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8))
    }

    private var succeeded: Bool { model.savedCount != nil || model.allSent }

    private var failure: String? {
        if let error = model.error ?? model.workspace.lastSaveError { return error }
        if case .failed(let reason) = model.entry?.state { return reason }
        return nil
    }
}
