import SwiftUI
import DrawspeakCore

public struct FeedbackPreviewSheet: View {
    @State private var model: FeedbackPreviewModel
    private let initialSelection: Set<UUID>?
    private let onClose: () -> Void

    public init(workspace: Workspace, canvasId: UUID, initialSelection: Set<UUID>? = nil, onClose: @escaping () -> Void) {
        _model = State(initialValue: FeedbackPreviewModel(workspace: workspace, canvasId: canvasId))
        self.initialSelection = initialSelection; self.onClose = onClose
    }
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let thread = model.frozenCanvas?.thread {
                        Text("To: \(thread.displayName)").font(.headline)
                        Text(thread.hostURL.host() ?? thread.hostURL.absoluteString).font(.subheadline).foregroundStyle(.secondary)
                    } else { Text("Connect this canvas to a T3 thread to send").font(.headline) }
                    if let count = model.savedCount {
                        Label("Draft Saved", systemImage: "doc.badge.checkmark").font(.title2)
                        Text("Saved as draft · \(count) comments. Nothing was sent.")
                        Button("Back to Canvas", action: onClose).frame(minHeight: 44)
                    } else if let entry = model.entry {
                        FeedbackDeliveryResult(model: model, entry: entry, onClose: onClose)
                    } else {
                        if model.pendingCount > 0 { Text("\(model.pendingCount) comments still recording or transcribing stay on the canvas").font(.subheadline) }
                        if !model.newNotes.isEmpty {
                            Button("\(model.newNotes.count) new comments are ready — Add", action: model.addNew).frame(minHeight: 44)
                        }
                        if model.repeatCount > 0 { Label("Includes comments already sent (\(model.repeatCount))", systemImage: "arrow.trianglehead.2.clockwise").font(.subheadline) }
                        if let canvas = model.frozenCanvas {
                            ForEach(snapshotIds, id: \.self) { id in
                                FeedbackSnapshotGroup(snapshot: canvas.snapshots.first { $0.id == id },
                                    title: groupTitle(id), notes: model.candidates.filter { $0.snapshotId == id }, model: model)
                            }
                        }
                        if model.candidates.isEmpty { ContentUnavailableView("No Ready Comments", systemImage: "text.bubble", description: Text("Add text to a comment on the canvas.")) }
                        if let reason = model.sendBlock { Text(reason).foregroundStyle(.red).font(.subheadline) }
                    }
                    if let error = model.error { Text(error).foregroundStyle(.red) }
                    if let error = model.workspace.lastSaveError { Text(error).foregroundStyle(.red) }
                }.padding()
            }
            .navigationTitle("Feedback")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", action: onClose).disabled(model.busy) } }
            .safeAreaInset(edge: .bottom) {
                if model.savedCount == nil && model.entry == nil {
                    VStack(spacing: 12) {
                        if model.busy { ProgressView("Preparing feedback…") }
                        Button("Send to Agent") { Task { await model.send() } }
                            .buttonStyle(.glassProminent).tint(Theme.action)
                            .disabled(model.busy || model.sendBlock != nil).frame(minHeight: 44)
                        Button("Save Draft") { Task { await model.save() } }
                            .disabled(model.busy || model.selection.isEmpty).frame(minHeight: 44)
                    }.frame(maxWidth: .infinity).padding().paletteBackground()
                }
            }
        }
        .interactiveDismissDisabled(model.busy)
        .presentationDragIndicator(.visible)
        .task { model.open(initialSelection: initialSelection) }
    }
    private var snapshotIds: [String] {
        var ids = model.package?.groups.map { $0.snapshot.id } ?? []
        for note in model.candidates where !ids.contains(note.snapshotId) { ids.append(note.snapshotId) }
        return ids
    }
    private func groupTitle(_ id: String) -> String {
        guard let snapshot = model.frozenCanvas?.snapshots.first(where: { $0.id == id }) else { return "Missing snapshot" }
        let screen = model.frozenCanvas?.screens.first { $0.id == snapshot.screenId }?.title ?? snapshot.screenId
        return "\(screen) · \(snapshot.role == .baseline ? "Now" : "\(snapshot.proposalId ?? "Proposal") · Iteration \(snapshot.iteration)")"
    }
}
