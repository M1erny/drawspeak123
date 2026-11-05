import SwiftUI
import DrawspeakCore

public struct FeedbackPreviewSheet: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: FeedbackPreviewModel
    @State private var confirmsClose = false
    private let initialSelection: Set<UUID>?
    private let onChooseThread: (() -> Void)?
    private let onClose: () -> Void

    public init(workspace: Workspace, canvasId: UUID, initialSelection: Set<UUID>? = nil, onChooseThread: (() -> Void)? = nil, onClose: @escaping () -> Void) {
        _model = State(initialValue: FeedbackPreviewModel(workspace: workspace, canvasId: canvasId))
        self.initialSelection = initialSelection; self.onChooseThread = onChooseThread; self.onClose = onClose
    }
    public var body: some View {
        NavigationStack {
            FeedbackPreviewContent(model: model, onChooseThread: onChooseThread)
                .navigationTitle(Text("Send Feedback", bundle: .module))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !model.showsResult {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .close, action: onClose).disabled(model.busy)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if model.showsResult {
                            Button(role: .confirm, action: done)
                                .disabled(model.busy)
                                .confirmationDialog(Text("Close Without Sending the Rest?", bundle: .module),
                                                    isPresented: $confirmsClose, titleVisibility: .visible) {
                                    Button(action: sendRemaining) { Text("Send Remaining", bundle: .module) }
                                    Button(role: .destructive, action: onClose) { Text("Close", bundle: .module) }
                                } message: {
                                    Text("\(model.sentCount) of \(model.series.count) messages arrived. Comments in the other messages stay unsent, so they are offered again in Send.", bundle: .module)
                                }
                        } else {
                            FeedbackSendAction(model: model, onChooseThread: onChooseThread)
                        }
                    }
                }
                .safeAreaBar(edge: .bottom) {
                    if !model.showsResult && !model.candidates.isEmpty {
                        FeedbackPreviewActions(model: model)
                    }
                }
        }
        .tint(.primary)
        .interactiveDismissDisabled(model.busy)
        .presentationSizing(.form)
        .task { model.open(initialSelection: initialSelection) }
        .onChange(of: model.workspace.canvas(model.canvasId)) { model.refresh() }
        .onChange(of: model.workspace.threads == nil) { model.refresh() }
        .onChange(of: scenePhase) { if scenePhase == .active { model.refresh() } }
    }

    private func done() {
        if model.isPartiallySent { confirmsClose = true } else { onClose() }
    }

    private func sendRemaining() { Task { await model.retry() } }
}
