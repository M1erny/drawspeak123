import SwiftUI
import Observation
import DrawspeakCore

@Observable
final class FeedbackPreviewModel {
    let workspace: Workspace
    let canvasId: UUID
    var candidates: [Note] = []
    var selection: Set<UUID> = [] { didSet { rebuild() } }
    var frozenCanvas: ReviewCanvas?
    var opened = false
    var busy = false
    var batchId: String?
    var savedCount: Int?
    var preparationFailed = false
    var error: String?
    var reconciliationNotice: String?

    init(workspace: Workspace, canvasId: UUID) { self.workspace = workspace; self.canvasId = canvasId }
    var entry: OutboxEntry? { workspace.canvas(canvasId)?.outbox.first { $0.id == batchId } }
    private(set) var pendingCount = 0
    private(set) var newNotes: [Note] = []
    private(set) var selected: [Note] = []
    private(set) var package: FeedbackPackage?
    private(set) var sendBlock: String?
    private(set) var snapshotGroups: [FeedbackPreviewGroup] = []
    private(set) var reasons: [UUID: String] = [:]
    var showsResult: Bool {
        if savedCount != nil || preparationFailed { return true }
        guard let entry else { return false }
        switch entry.state {
        case .uploading, .sending: return false
        default: return true
        }
    }
    var recipient: ThreadBinding? { entry?.thread ?? workspace.canvas(canvasId)?.thread }

    func refresh() {
        guard let scope = workspace.feedbackScope(canvasId: canvasId) else { return }
        pendingCount = scope.pending.count(where: { $0.isRecording || $0.isTranscribing })
        let existing = Set(candidates.map(\.id))
        newNotes = scope.ready.filter { !existing.contains($0.id) }
        // Source captures can finish while the preview is open; note revisions stay frozen.
        if let current = workspace.canvas(canvasId) {
            frozenCanvas?.snapshots = current.snapshots
            frozenCanvas?.screens = current.screens
        }
        rebuild()
    }

    func reason(for note: Note) -> String? { reasons[note.id] }

    private func readinessReason(_ note: Note, canvas: ReviewCanvas) -> String? {
        var checked = note
        checked.lastSentRevision = nil
        if case .sourceUnavailable(let reason) = FeedbackScope.readiness(of: checked, in: canvas, sourceAvailable: workspace.isSourceAvailable) {
            switch reason {
            case "Mark is not valid": return String(localized: "Invalid mark", bundle: .module)
            case "Snapshot is missing": return String(localized: "Screen missing", bundle: .module)
            case "Component target does not match this version": return String(localized: "Component changed", bundle: .module)
            case FeedbackScope.captureMissingReason: return String(localized: "Preparing…", bundle: .module)
            default: return String(localized: "File missing", bundle: .module)
            }
        }
        if !note.hasText || note.isRecording || (note.isTranscribing && !note.hasText) {
            return String(localized: "Not ready", bundle: .module)
        }
        guard canvas.snapshots.first(where: { $0.id == note.snapshotId })?.image != nil else {
            return String(localized: "Image missing", bundle: .module)
        }
        return nil
    }

    /// Called only on selection or workspace changes, never from a view getter.
    private func rebuild() {
        guard var canvas = frozenCanvas else { return }
        selected = candidates.filter { selection.contains($0.id) }
        reasons = Dictionary(uniqueKeysWithValues: candidates.compactMap { note in
            readinessReason(note, canvas: canvas).map { (note.id, $0) }
        })
        canvas.notes = selected
        let thread = recipient ?? ThreadBinding(hostURL: URL(filePath: "/"), threadId: "", threadTitle: "", projectId: nil, projectTitle: nil)
        package = FeedbackPackageBuilder.build(canvas: canvas, noteIds: selection, thread: thread, batchId: batchId ?? "preview", now: workspace.now())
        sendBlock = nil
        if let package {
            do { try FeedbackPayloadBuilder.validate(package) }
            catch { sendBlock = error.localizedDescription }
        }
        if selected.contains(where: { reasons[$0.id] != nil }) {
            sendBlock = String(localized: "Deselect unavailable comments", bundle: .module)
        }
        let ids = candidates.reduce(into: [String]()) { if !$0.contains($1.snapshotId) { $0.append($1.snapshotId) } }
        snapshotGroups = ids.map { id in
            let snapshot = canvas.snapshots.first { $0.id == id }
            let notes = candidates.filter { $0.snapshotId == id }
            return FeedbackPreviewGroup(id: id, snapshot: snapshot, title: groupTitle(snapshot, canvas: canvas), notes: notes,
                items: notes.filter { selection.contains($0.id) }.map(BatchItem.init(note:)))
        }
    }

    private func groupTitle(_ snapshot: Snapshot?, canvas: ReviewCanvas) -> String {
        guard let snapshot else { return String(localized: "Screen missing", bundle: .module) }
        let screen = canvas.screens.first { $0.id == snapshot.screenId }?.title ?? String(localized: "Screen", bundle: .module)
        if snapshot.role == .baseline { return String(localized: "\(screen) · Now", bundle: .module) }
        let screenModel = canvas.screens.first { $0.id == snapshot.screenId }
        let ids = screenModel.map { CanvasLayout.proposalIds(in: canvas, screen: $0) } ?? []
        let index = ids.firstIndex(of: snapshot.proposalId ?? "") ?? 0
        let letter = index < 26 ? String(UnicodeScalar(65 + index)!) : String(index + 1)
        let proposal = String(localized: "Proposal \(letter)", bundle: .module)
        return String(localized: "\(screen) · \(proposal) · Version \(snapshot.iteration)", bundle: .module)
    }
    func open(initialSelection: Set<UUID>?) {
        guard !opened, let canvas = workspace.canvas(canvasId), let scope = workspace.feedbackScope(canvasId: canvasId) else { return }
        opened = true
        frozenCanvas = canvas
        let ids = Set(scope.ready.map(\.id) + scope.unavailable.map { $0.note.id }).union(initialSelection ?? [])
        candidates = canvas.notes.filter { ids.contains($0.id) }.sorted { $0.ordinal < $1.ordinal }
        selection = (initialSelection ?? ids).intersection(Set(candidates.map(\.id)))
        refresh()
    }
    func addNew() {
        let additions = newNotes
        candidates.append(contentsOf: additions)
        selection.formUnion(additions.map(\.id))
        // Refresh immutable source metadata only for explicitly added notes.
        if let canvas = workspace.canvas(canvasId) { frozenCanvas?.snapshots = canvas.snapshots; frozenCanvas?.screens = canvas.screens }
        candidates.sort { $0.ordinal < $1.ordinal }
        refresh()
    }
    func send() async {
        refresh()
        guard !busy, !selection.isEmpty, sendBlock == nil, recipient != nil, workspace.threads != nil else { return }
        batchId = Workspace.newBatchId(now: workspace.now())
        rebuild()
        guard let package else { return }
        busy = true; error = nil; preparationFailed = false
        defer { busy = false }
        do {
            let attachments = try await FeedbackPayloadBuilder.attachments(for: package, blobs: workspace.blobs)
            guard await workspace.send(package: package, attachments: attachments, canvasId: canvasId) != nil else { preparationFailed = true; error = String(localized: "Canvas unavailable.", bundle: .module); return }
            await workspace.saveNow()
        } catch { preparationFailed = true; self.error = error.localizedDescription }
    }
    func save() async {
        guard !busy, !selection.isEmpty else { return }
        guard selected.allSatisfy({ workspace.note($0.id, canvasId: canvasId).map(BatchItem.init(note:)) == BatchItem(note: $0) }) else {
            error = String(localized: "Comments changed. Reopen to update.", bundle: .module); return
        }
        busy = true
        defer { busy = false }
        if let draft = workspace.saveDraft(noteIds: selection, canvasId: canvasId) {
            await workspace.saveNow()
            if let failure = workspace.lastSaveError { error = failure } else { savedCount = draft.items.count }
        } else { error = String(localized: "Couldn't save draft.", bundle: .module) }
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
        reconciliationNotice = result == .notFound ? String(localized: "Not found in thread. Sending again may duplicate it.", bundle: .module) : result == .unavailable ? String(localized: "Can't reach thread.", bundle: .module) : nil
        await workspace.saveNow()
        busy = false
    }
}
