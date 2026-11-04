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
    var selectedPhoto: PhotosPickerItem?
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
        selectedPhoto = nil
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
        let camera = CanvasFraming.fitAll(canvas: canvas, viewSize: viewSize, insets: ShellMetrics.framingInsets)
        workspace.updateCamera(camera, canvasId: canvas.id)
    }

    /// A canvas that was never framed opens with everything visible. While the
    /// person has not moved the camera, resizing the window frames it again.
    func frameIfNeeded() {
        guard let canvas = workspace.currentCanvas, viewSize.width > 200, viewSize.height > 200,
              !canvas.screens.isEmpty,
              canvas.camera == CameraState() || canvas.camera == autoFramedCamera else { return }
        let camera = CanvasFraming.fitAll(canvas: canvas, viewSize: viewSize, insets: ShellMetrics.framingInsets)
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
                                               viewSize: viewSize, insets: ShellMetrics.framingInsets) else { return }
        workspace.updateCamera(camera, canvasId: updated.id)
    }

    /// The inspector column narrows the canvas; pan so the focused mark stays in view.
    func keepFocusedMarkVisible() {
        guard let noteId = workspace.focusedNoteId, let canvas = workspace.currentCanvas, viewSize != .zero,
              let rect = CanvasFraming.markScreenRect(noteId: noteId, in: canvas, camera: canvas.camera) else { return }
        let margin = ShellMetrics.markMargin
        let overflow = rect.maxX - (viewSize.width - margin)
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
        let url: URL
        switch result {
        case .success(let urls):
            guard let first = urls.first else { return }
            url = first
        case .failure(let error):
            if (error as? CocoaError)?.code == .userCancelled { return }
            alert = .importFailed(ImportFailure(error).message)
            return
        }
        guard !isImportingFile, let canvasId = importCanvasId ?? workspace.currentCanvasId else { return }
        isImportingFile = true
        defer { isImportingFile = false }
        show(CanvasStatus(text: AttributedString(localized: "Reading File…")))
        let outcome = await importer.read(url, canvasId: canvasId) { [weak self] page, count in
            self?.show(CanvasStatus(text: AttributedString(localized: "Rendering Page \(page) of \(count)…")))
        }
        status = nil
        switch outcome {
        case .success(let pages):
            if pages.count > 1 {
                do {
                    for (index, pending) in pages.enumerated() {
                        show(CanvasStatus(text: AttributedString(localized: "Adding Page \(index + 1) of \(pages.count)…")))
                        _ = try importer.store(pending, target: .newScreen(title: pending.suggestedTitle), in: workspace)
                        await Task.yield()
                    }
                    show(CanvasStatus(text: AttributedString(localized: "Added \(pages.count) Pages")))
                    if canvasId == workspace.currentCanvasId { fitAll() }
                } catch {
                    status = nil
                    alert = .importFailed(ImportFailure(error).message)
                }
                return
            }
            guard let pending = pages.first else { return }
            presentImport(pending)
        case .failure(let failure):
            alert = .importFailed(failure.message)
        }
    }

    func handlePhoto(_ photo: PhotosPickerItem) async {
        guard !isImportingFile, let canvasId = importCanvasId ?? workspace.currentCanvasId else { return }
        isImportingFile = true
        defer { isImportingFile = false }
        show(CanvasStatus(text: AttributedString(localized: "Loading Photo…")))
        do {
            guard let data = try await photo.loadTransferable(type: Data.self) else { throw ImportFailure.unreadable }
            let outcome = await ImportCoordinator.readPhoto(data, canvasId: canvasId, title: String(localized: "Photo"))
            status = nil
            switch outcome {
            case .success(let pending): presentImport(pending)
            case .failure(let failure): alert = .importFailed(failure.message)
            }
        } catch {
            status = nil
            alert = .importFailed(ImportFailure(error).message)
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
        Task {
            let report = await workspace.pull(canvasId: canvasId, captureHTML: HTMLCaptureAdapter.capture)
            isPulling = false
            if report.importedSnapshots > 0 {
                show(CanvasStatus(text: AttributedString(localized: "Added ^[\(report.importedSnapshots) version](inflect: true)",
                                                         comment: "Count of versions pulled from the thread.")))
                fitAll()
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
