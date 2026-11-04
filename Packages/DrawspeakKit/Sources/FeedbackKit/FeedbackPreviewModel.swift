import SwiftUI
import Observation
import DrawspeakCore

@Observable
final class FeedbackPreviewModel {
    let workspace: Workspace
    let canvasId: UUID
    var candidates: [Note] = []
    var selection: Set<UUID> = []
    var frozenCanvas: ReviewCanvas?
    var opened = false
    var busy = false
    var batchId: String?
    var savedCount: Int?
    var error: String?
    var reconciliationNotice: String?

    init(workspace: Workspace, canvasId: UUID) { self.workspace = workspace; self.canvasId = canvasId }
    var entry: OutboxEntry? { workspace.canvas(canvasId)?.outbox.first { $0.id == batchId } }
    var pendingCount: Int { workspace.feedbackScope(canvasId: canvasId)?.pending.filter { $0.isRecording || $0.isTranscribing }.count ?? 0 }
    var newNotes: [Note] { workspace.feedbackScope(canvasId: canvasId)?.ready.filter { note in !candidates.contains { $0.id == note.id } } ?? [] }
    var selected: [Note] { candidates.filter { selection.contains($0.id) } }
    var repeatCount: Int { selected.filter { $0.lastSentRevision != nil }.count }
    var package: FeedbackPackage? {
        guard var canvas = frozenCanvas else { return nil }
        canvas.notes = selected
        let thread = canvas.thread ?? ThreadBinding(hostURL: URL(filePath: "/"), threadId: "", threadTitle: "No recipient", projectId: nil, projectTitle: nil)
        return FeedbackPackageBuilder.build(canvas: canvas, noteIds: selection, thread: thread, batchId: batchId ?? "preview", now: workspace.now())
    }
    func reason(for note: Note) -> String? {
        guard let canvas = frozenCanvas else { return "Canvas is missing" }
        var checkedNote = note
        checkedNote.lastSentRevision = nil
        if case .sourceUnavailable(let reason) = FeedbackScope.readiness(of: checkedNote, in: canvas, sourceAvailable: workspace.isSourceAvailable) { return reason }
        if !note.hasText || note.isRecording || (note.isTranscribing && !note.hasText) { return "Comment is not ready" }
        guard let snapshot = canvas.snapshots.first(where: { $0.id == note.snapshotId }), snapshot.image != nil else { return "Capture image is missing" }
        return nil
    }
    var sendBlock: String? {
        if selected.isEmpty { return "Select at least one comment." }
        if let note = selected.first(where: { reason(for: $0) != nil }) { return "Comment \(note.ordinal): \(reason(for: note) ?? "Unavailable") — deselect to send the rest" }
        if let package { do { try FeedbackPayloadBuilder.validate(package) } catch { return error.localizedDescription } }
        if frozenCanvas?.thread == nil { return "Connect this canvas to a T3 thread to send" }
        if workspace.threads == nil { return "Connect to T3 Code to send. You can save a draft." }
        return nil
    }
    func open(initialSelection: Set<UUID>?) {
        guard !opened, let canvas = workspace.canvas(canvasId), let scope = workspace.feedbackScope(canvasId: canvasId) else { return }
        opened = true
        frozenCanvas = canvas
        let ids = Set(scope.ready.map(\.id) + scope.unavailable.map { $0.note.id }).union(initialSelection ?? [])
        candidates = canvas.notes.filter { ids.contains($0.id) }.sorted { $0.ordinal < $1.ordinal }
        selection = initialSelection ?? ids
    }
    func addNew() {
        let additions = newNotes
        candidates.append(contentsOf: additions)
        selection.formUnion(additions.map(\.id))
        // Refresh immutable source metadata only for explicitly added notes.
        if let canvas = workspace.canvas(canvasId) { frozenCanvas?.snapshots = canvas.snapshots; frozenCanvas?.screens = canvas.screens }
        candidates.sort { $0.ordinal < $1.ordinal }
    }
    func send() async {
        guard !busy, sendBlock == nil else { return }
        batchId = Workspace.newBatchId(now: workspace.now())
        guard let package else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let attachments = try await FeedbackPayloadBuilder.attachments(for: package, blobs: workspace.blobs)
            guard await workspace.send(package: package, attachments: attachments, canvasId: canvasId) != nil else { error = "Canvas is no longer available."; return }
            await workspace.saveNow()
        } catch { self.error = error.localizedDescription }
    }
    func save() async {
        guard !busy, !selection.isEmpty else { return }
        guard selected.allSatisfy({ workspace.note($0.id, canvasId: canvasId).map(BatchItem.init(note:)) == BatchItem(note: $0) }) else {
            error = "Comments changed while previewing. Reopen Feedback to save the current revisions."; return
        }
        busy = true
        defer { busy = false }
        if let draft = workspace.saveDraft(noteIds: selection, canvasId: canvasId) {
            await workspace.saveNow()
            if let failure = workspace.lastSaveError { error = failure } else { savedCount = draft.items.count }
        } else { error = "Could not save this draft." }
    }
    func retry() async {
        guard !busy, let batchId else { return }
        busy = true
        await workspace.deliver(batchId: batchId, canvasId: canvasId)
        await workspace.saveNow()
        busy = false
    }
    func reconcile() async {
        guard !busy, let batchId else { return }
        busy = true
        let result = await workspace.reconcile(batchId: batchId, canvasId: canvasId)
        reconciliationNotice = result == .notFound ? "No message found. Sending again might duplicate delivery if the thread check was wrong." : result == .unavailable ? "Could not check the thread. Try again when connected." : nil
        await workspace.saveNow()
        busy = false
    }
}
