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
    /// The To row chose New Thread, including when replacing a bound thread.
    var startsNewThread = false
    var newThreadTitle = ""
    var newThreadProjectId: String?
    private(set) var projects: [ProjectSummary] = []
    private(set) var loadingProjects = false
    private(set) var projectsError: String?

    init(workspace: Workspace, canvasId: UUID) { self.workspace = workspace; self.canvasId = canvasId }
    var annotationStyle: AnnotationStyle { Self.storedAnnotationStyle }

    static var storedAnnotationStyle: AnnotationStyle {
        let defaults = UserDefaults.standard
        return AnnotationStyle(
            lineWidth: defaults.object(forKey: "drawspeak.markLineWidth") == nil ? AnnotationStyle.standard.lineWidth : defaults.double(forKey: "drawspeak.markLineWidth"),
            pinSize: defaults.object(forKey: "drawspeak.pinSize") == nil ? AnnotationStyle.standard.pinSize : defaults.double(forKey: "drawspeak.pinSize")
        )
    }

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
    var canStartNewThread: Bool { workspace.threads != nil }
    var newThreadReady: Bool {
        startsNewThread && canStartNewThread && newThreadProjectId != nil
            && !newThreadTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func chooseNewThread() {
        startsNewThread = true
        if newThreadTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newThreadTitle = workspace.canvas(canvasId)?.title ?? ""
        }
    }

    func loadProjects() async {
        guard startsNewThread, !loadingProjects, let threads = workspace.threads else { return }
        loadingProjects = true
        defer { loadingProjects = false }
        do {
            let result = try await threads.listProjects()
            projects = result
            projectsError = nil
            if !result.contains(where: { $0.id == newThreadProjectId }) {
                newThreadProjectId = Self.defaultProjectId(in: result, canvases: workspace.document.canvases)
            }
        } catch {
            projectsError = error.localizedDescription
        }
    }

    /// The project of the most recently used thread, else the first project.
    static func defaultProjectId(in projects: [ProjectSummary], canvases: [ReviewCanvas]) -> String? {
        let recent = canvases.compactMap { canvas -> (id: String, usedAt: Date)? in
            guard let id = canvas.thread?.projectId else { return nil }
            return (id, canvas.outbox.map(\.createdAt).max() ?? canvas.updatedAt)
        }.sorted { $0.usedAt > $1.usedAt }
        return recent.first { used in projects.contains { $0.id == used.id } }?.id ?? projects.first?.id
    }

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

    func displayNumber(for note: Note) -> Int? {
        workspace.displayNumber(for: note.id, canvasId: canvasId)
    }

    private func previewItem(for note: Note) -> BatchItem {
        var item = BatchItem(note: note)
        item.displayNumber = displayNumber(for: note)
        return item
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
        let numbers = Dictionary(uniqueKeysWithValues: candidates.compactMap { note in
            displayNumber(for: note).map { (note.id, $0) }
        })
        package = FeedbackPackageBuilder.build(canvas: canvas, noteIds: selection, thread: thread,
            batchId: batchId ?? "preview", now: workspace.now(), displayNumbers: numbers)
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
                items: notes.filter { selection.contains($0.id) }.map(previewItem(for:)))
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
        let toNewThread = startsNewThread
        guard !busy, !selection.isEmpty, sendBlock == nil, workspace.threads != nil, toNewThread ? newThreadReady : recipient != nil else { return }
        if toNewThread, workspace.pendingNewThreadEntry(canvasId: canvasId) != nil {
            error = String(localized: "A new thread from this canvas isn't confirmed yet.", bundle: .module); return
        }
        batchId = Workspace.newBatchId(now: workspace.now())
        rebuild()
        guard let package else { return }
        busy = true; error = nil; preparationFailed = false
        defer { busy = false }
        do {
            let attachments = try await FeedbackPayloadBuilder.attachments(for: package, blobs: workspace.blobs, style: annotationStyle)
            let entry: OutboxEntry?
            if toNewThread, let projectId = newThreadProjectId {
                entry = await workspace.sendToNewThread(
                    package: package, attachments: attachments, canvasId: canvasId, projectId: projectId,
                    projectTitle: projects.first { $0.id == projectId }?.title, threadTitle: newThreadTitle
                )
            } else {
                entry = await workspace.send(package: package, attachments: attachments, canvasId: canvasId)
            }
            guard entry != nil else { preparationFailed = true; error = String(localized: "Canvas unavailable.", bundle: .module); return }
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
        let startsThread = entry?.newThread != nil
        let result = await workspace.reconcile(batchId: batchId, canvasId: canvasId)
        reconciliationNotice = switch result {
        case .found: nil
        case .notFound: String(localized: "Not found in thread. Sending again may duplicate it.", bundle: .module)
        case .unavailable where startsThread: String(localized: "Couldn't confirm the new thread.", bundle: .module)
        case .unavailable: String(localized: "Can't reach thread.", bundle: .module)
        }
        await workspace.saveNow()
        busy = false
    }
}
