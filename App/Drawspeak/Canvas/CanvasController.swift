import CanvasKit
import DrawspeakCore
import Foundation
import Observation
import PhotosUI
import SwiftUI

/// Presentation state and actions of the canvas detail: tools, sheets, the
/// Send popover, the Comments inspector, import, pull and camera framing.
@MainActor
@Observable
final class CanvasController {
    let workspace: Workspace

    var tool: CanvasTool = .region
    var sheet: CanvasSheet?
    var showsFeedback = false
    private(set) var feedbackSelection: Set<UUID>?
    var showsInspector = false
    var showsImporter = false
    var showsPhotoPicker = false
    var selectedPhotos: [PhotosPickerItem] = []
    /// The most photos or files one import adds; each becomes its own screen.
    static let maxImportCount = 20
    @ObservationIgnored private var importCanvasId: UUID?
    var showsSqueezePalette = false
    var squeezeAnchor: CGPoint?
    var alert: CanvasAlert?
    private(set) var status: CanvasStatus?
    private(set) var isImportingFile = false
    private(set) var isPulling = false
    private(set) var undoTick = 0
    /// The canvas size, set from layout; framing uses it.
    var viewSize: CGSize = .zero
    /// Whether Comments float over the canvas (regular width) instead of presenting as a sheet.
    var usesInspectorPanel = false

    /// Width at the canvas's trailing edge covered by the Comments panel.
    var inspectorCoverage: CGFloat {
        showsInspector && usesInspectorPanel ? ShellMetrics.inspectorWidth.ideal + ShellMetrics.inspectorPanelInset * 2 : 0
    }

    /// Framing margins; the panel is added to the trailing side while it is open.
    private var framingInsets: EdgeInsets {
        var insets = ShellMetrics.framingInsets
        insets.trailing += inspectorCoverage
        return insets
    }
    /// The camera set by automatic framing; replaced as long as the person has not moved it.
    private var autoFramedCamera: CameraState?

    @ObservationIgnored private let importer = ImportCoordinator()
    /// Set when the thread picker was opened from the Send popover.
    @ObservationIgnored private var feedbackAfterSheet: Set<UUID>?
    @ObservationIgnored private var reopensFeedback = false

    init(workspace: Workspace) {
        self.workspace = workspace
    }

    var isBusy: Bool { isImportingFile || isPulling }
    var hasThread: Bool { workspace.currentCanvas?.thread != nil }
    var zoom: Double { workspace.currentCanvas?.camera.zoom ?? 1 }

    var canUndo: Bool { _ = undoTick; return workspace.undoManager?.canUndo ?? false }
    var canRedo: Bool { _ = undoTick; return workspace.undoManager?.canRedo ?? false }

    /// The current canvas title, renamed from the title menu.
    var canvasTitle: String {
        get { workspace.currentCanvas?.title ?? "" }
        set {
            let title = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let canvasId = workspace.currentCanvasId, !title.isEmpty else { return }
            workspace.renameCanvas(canvasId, title: title)
        }
    }

    /// Drives the microphone alert; dismissing it clears the issue.
    var showsVoiceIssue: Bool {
        get { workspace.voiceIssue != nil }
        set { if !newValue { workspace.clearVoiceIssue() } }
    }

    // MARK: - Presentation

    func requestImport() {
        guard !isImportingFile else { return }
        importCanvasId = workspace.currentCanvasId
        showsImporter = true
    }

    func requestPhotoLibrary() {
        guard !isImportingFile else { return }
        importCanvasId = workspace.currentCanvasId
        selectedPhotos = []
        showsPhotoPicker = true
    }
    func showSettings() { sheet = .settings }
    func showHistory() { sheet = .history }
    func chooseThread() { sheet = .threadPicker(thenFeedback: nil) }
    func addRegion() { sheet = .addRegion(snapshotId: nil) }
    func addRegion(snapshotId: String) { sheet = .addRegion(snapshotId: snapshotId) }
    func toggleSqueezePalette() { showsSqueezePalette.toggle() }

    func openFeedback(selection: Set<UUID>? = nil) {
        feedbackSelection = selection
        showsFeedback = true
    }

    func closeFeedback() { showsFeedback = false }

    /// From the Send popover: pick a thread, then come back to the same preview.
    func chooseThreadForFeedback() {
        showsFeedback = false
        sheet = .threadPicker(thenFeedback: feedbackSelection ?? [])
    }

    func resumeDraft(_ noteIds: Set<UUID>) {
        feedbackAfterSheet = noteIds
        reopensFeedback = true
        sheet = nil
    }

    func threadBound(returnSelection: Set<UUID>?) {
        guard let returnSelection else { return }
        feedbackAfterSheet = returnSelection.isEmpty ? nil : returnSelection
        reopensFeedback = true
    }

    /// A popover can only appear once the sheet is gone.
    func sheetDismissed() {
        guard reopensFeedback else { return }
        reopensFeedback = false
        openFeedback(selection: feedbackAfterSheet)
        feedbackAfterSheet = nil
    }

    /// Selecting an existing comment opens the inspector. A mark that was just
    /// drawn does not: its live text appears in the bubble on the canvas.
    func focusedNoteChanged(_ noteId: UUID?) {
        guard let noteId, let note = workspace.note(noteId) else { return }
        let isNew = Date().timeIntervalSince(note.createdAt) < 2
        guard !isNew, workspace.activeRecording?.noteId != noteId else { return }
        showsInspector = true
        keepFocusedMarkVisible()
    }

    func clearStatus(_ id: UUID) {
        if status?.id == id, !isImportingFile { status = nil }
    }

    // MARK: - Undo

    func undo() {
        workspace.undoManager?.undo()
        undoTick += 1
    }

    func redo() {
        workspace.undoManager?.redo()
        undoTick += 1
    }

    func undoStackChanged() { undoTick += 1 }

    // MARK: - Camera

    func zoomIn() { zoom(by: 1.25) }
    func zoomOut() { zoom(by: 0.8) }

    func actualSize() {
        guard let canvas = workspace.currentCanvas else { return }
        zoom(by: 1 / canvas.camera.zoom)
    }

    func fitAll() {
        guard let canvas = workspace.currentCanvas, viewSize != .zero else { return }
        let camera = CanvasFraming.fitAll(canvas: canvas, viewSize: viewSize, insets: framingInsets)
        workspace.updateCamera(camera, canvasId: canvas.id)
    }

    /// A canvas that was never framed opens with everything visible. While the
    /// person has not moved the camera, resizing the window frames it again.
    func frameIfNeeded() {
        guard let canvas = workspace.currentCanvas, viewSize.width > 200, viewSize.height > 200,
              !canvas.screens.isEmpty,
              canvas.camera == CameraState() || canvas.camera == autoFramedCamera else { return }
        let camera = CanvasFraming.fitAll(canvas: canvas, viewSize: viewSize, insets: framingInsets)
        autoFramedCamera = camera
        workspace.updateCamera(camera, canvasId: canvas.id)
    }

    /// Show on Canvas: select the note's own version and frame its mark.
    func showSource(_ noteId: UUID) {
        guard let canvas = workspace.currentCanvas, let note = canvas.notes.first(where: { $0.id == noteId }),
              let snapshot = canvas.snapshots.first(where: { $0.id == note.snapshotId }) else { return }
        let lane = LaneKey(screenId: snapshot.screenId, proposalId: snapshot.role == .baseline ? nil : snapshot.proposalId)
        workspace.selectVersion(snapshot.id, lane: lane)
        workspace.focusedNoteId = noteId
        guard let updated = workspace.currentCanvas,
              let camera = CanvasFraming.frame(snapshotId: snapshot.id, rect: note.shape.bounds, in: updated,
                                               viewSize: viewSize, insets: framingInsets) else { return }
        workspace.updateCamera(camera, canvasId: updated.id)
    }

    /// The Comments panel covers the canvas's trailing edge; pan so the focused mark stays in view.
    func keepFocusedMarkVisible() {
        guard let noteId = workspace.focusedNoteId, let canvas = workspace.currentCanvas, viewSize != .zero,
              let rect = CanvasFraming.markScreenRect(noteId: noteId, in: canvas, camera: canvas.camera) else { return }
        let margin = ShellMetrics.markMargin
        let overflow = rect.maxX - (viewSize.width - inspectorCoverage - margin)
        guard overflow > 0 else { return }
        var camera = canvas.camera
        camera.offsetX -= min(overflow, max(rect.minX - margin, 0))
        workspace.updateCamera(camera, canvasId: canvas.id)
    }

    private func zoom(by factor: Double) {
        guard let canvas = workspace.currentCanvas else { return }
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        workspace.updateCamera(CanvasFraming.zoomed(canvas.camera, by: factor, around: center), canvasId: canvas.id)
    }

    // MARK: - Import and pull

    func handleImport(_ result: Result<[URL], any Error>) async {
        let urls: [URL]
        switch result {
        case .success(let picked):
            urls = Array(picked.prefix(Self.maxImportCount))
        case .failure(let error):
            if (error as? CocoaError)?.code == .userCancelled { return }
            alert = .importFailed(ImportFailure(error).message)
            return
        }
        guard !urls.isEmpty, !isImportingFile, let canvasId = importCanvasId ?? workspace.currentCanvasId else { return }
        isImportingFile = true
        defer { isImportingFile = false }
        var pending: [PendingImport] = []
        var failures: [String] = []
        for (index, url) in urls.enumerated() {
            show(CanvasStatus(text: urls.count > 1
                ? AttributedString(localized: "Reading File \(index + 1) of \(urls.count)…")
                : AttributedString(localized: "Reading File…")))
            let outcome = await importer.read(url, canvasId: canvasId) { [weak self] page, count in
                self?.show(CanvasStatus(text: AttributedString(localized: "Rendering Page \(page) of \(count)…")))
            }
            switch outcome {
            case .success(let pages): pending.append(contentsOf: pages)
            case .failure(let failure): failures.append(urls.count > 1 ? "\(url.lastPathComponent): \(failure.message)" : failure.message)
            }
        }
        status = nil
        if urls.count == 1, pending.count == 1, let only = pending.first {
            presentImport(only)
        } else if !pending.isEmpty {
            addAsNewScreens(pending, canvasId: canvasId)
        }
        if !failures.isEmpty { alert = .importFailed(failures.prefix(3).joined(separator: "\n")) }
    }

    /// Several photos or files at once: each becomes its own screen, then the canvas frames them.
    private func addAsNewScreens(_ items: [PendingImport], canvasId: UUID) {
        var added = 0
        for (index, item) in items.enumerated() {
            show(CanvasStatus(text: AttributedString(localized: "Adding \(index + 1) of \(items.count)…")))
            do {
                _ = try importer.store(item, target: .newScreen(title: item.suggestedTitle), in: workspace)
                added += 1
            } catch {
                alert = .importFailed(ImportFailure(error).message)
                break
            }
        }
        guard added > 0 else { status = nil; return }
        show(CanvasStatus(text: AttributedString(localized: "Added ^[\(added) screen](inflect: true)", comment: "Count of imported screens.")))
        if canvasId == workspace.currentCanvasId { fitAll() }
    }

    func handlePhotos(_ photos: [PhotosPickerItem]) async {
        let photos = Array(photos.prefix(Self.maxImportCount))
        guard !photos.isEmpty, !isImportingFile, let canvasId = importCanvasId ?? workspace.currentCanvasId else { return }
        isImportingFile = true
        defer { isImportingFile = false }
        var pending: [PendingImport] = []
        var failures: [String] = []
        for (index, photo) in photos.enumerated() {
            show(CanvasStatus(text: photos.count > 1
                ? AttributedString(localized: "Loading Photo \(index + 1) of \(photos.count)…")
                : AttributedString(localized: "Loading Photo…")))
            let title = photos.count > 1 ? String(localized: "Photo \(index + 1)") : String(localized: "Photo")
            do {
                guard let data = try await photo.loadTransferable(type: Data.self) else { throw ImportFailure.unreadable }
                switch await ImportCoordinator.readPhoto(data, canvasId: canvasId, title: title) {
                case .success(let item): pending.append(item)
                case .failure(let failure): failures.append(failure.message)
                }
            } catch {
                failures.append(ImportFailure(error).message)
            }
        }
        status = nil
        selectedPhotos = []
        if photos.count == 1, let only = pending.first {
            presentImport(only)
        } else if !pending.isEmpty {
            addAsNewScreens(pending, canvasId: canvasId)
        }
        if !failures.isEmpty {
            alert = .importFailed(Set(failures).prefix(3).joined(separator: "\n"))
        }
    }

    private func presentImport(_ pending: PendingImport) {
        if workspace.canvas(pending.canvasId)?.screens.isEmpty ?? true {
            finishImport(pending, target: .newScreen(title: pending.suggestedTitle))
        } else {
            sheet = .importTarget(pending)
        }
    }

    func finishImport(_ pending: PendingImport, target: Workspace.ImportTarget) {
        do {
            _ = try importer.store(pending, target: target, in: workspace)
            show(CanvasStatus(text: AttributedString(localized: "Added to \(screenTitle(for: target, pending: pending))",
                                                     comment: "Placeholder is the screen title.")))
            if pending.canvasId == workspace.currentCanvasId, workspace.currentCanvas?.snapshots.count == 1 { fitAll() }
        } catch {
            alert = .importFailed(ImportFailure(error).message)
        }
    }

    func pull() {
        guard let canvasId = workspace.currentCanvasId, !isPulling else { return }
        isPulling = true
        show(CanvasStatus(text: AttributedString(localized: "Pulling Versions…")))
        Task {
            let report = await workspace.pull(canvasId: canvasId, captureHTML: HTMLCaptureAdapter.capture)
            isPulling = false
            status = nil
            if report.importedSnapshots > 0 {
                show(CanvasStatus(text: AttributedString(localized: "Added ^[\(report.importedSnapshots) version](inflect: true)",
                                                         comment: "Count of versions pulled from the thread.")))
                fitAll()
            } else if let reason = report.noVersionsReason {
                alert = .noVersions(reason)
            } else if report.issues.isEmpty {
                show(CanvasStatus(text: AttributedString(localized: "No New Versions")))
            } else {
                alert = .pullFailed(report.issues.prefix(3).joined(separator: "\n"))
            }
        }
    }

    func saveFailed(_ message: String?) {
        guard let message else { return }
        alert = .saveFailed(message)
    }

    private func show(_ status: CanvasStatus) {
        self.status = status
    }

    private func screenTitle(for target: Workspace.ImportTarget, pending: PendingImport) -> String {
        switch target {
        case .newScreen(let title):
            title
        case .baseline(let screenId), .proposal(let screenId, _):
            workspace.canvas(pending.canvasId)?.screens.first { $0.id == screenId }?.title ?? pending.suggestedTitle
        }
    }
}
