import CanvasKit
import DrawspeakCore
import FeedbackKit
import NotesKit
import SwiftUI
import T3Kit

/// The full-window review canvas with its floating palettes and on-demand panels.
struct CanvasScreen: View {
    let model: AppModel
    @Bindable var workspace: Workspace

    @Environment(\.undoManager) private var undoManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage(AppPreferences.drawWithFinger) private var drawWithFinger = false

    @State private var tool: CanvasTool = .region
    @State private var sheet: CanvasSheet?
    @State private var isImporting = false
    @State private var importer = ImportCoordinator()
    @State private var banner: CanvasBanner?
    @State private var isPulling = false
    @State private var squeezeAnchor: CGPoint?
    @State private var showsSqueezePalette = false
    @State private var viewSize: CGSize = .zero
    @State private var undoTick = 0

    var body: some View {
        ZStack {
            CanvasView(
                workspace: workspace,
                tool: $tool,
                drawWithFinger: drawWithFinger,
                overlayInsets: EdgeInsets(top: 88, leading: 16, bottom: 96, trailing: 16),
                squeezeAnchor: $squeezeAnchor,
                onSqueeze: { showsSqueezePalette.toggle() },
                onAddRegion: { _ in sheet = .addRegion }
            )
            .ignoresSafeArea()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { viewSize = $0 }

            if workspace.currentCanvas?.screens.isEmpty ?? true {
                EmptyCanvasView(
                    onImport: { isImporting = true },
                    onPull: workspace.currentCanvas?.thread == nil ? nil : { pull() }
                )
            }

            CanvasChrome(
                workspace: workspace,
                connection: model.connection,
                tool: $tool,
                isPulling: isPulling,
                canUndo: canUndo,
                canRedo: canRedo,
                actions: chromeActions
            )

            if showsSqueezePalette, let squeezeAnchor {
                ToolPalette(tool: $tool, canUndo: canUndo, canRedo: canRedo, onUndo: undo, onRedo: redo)
                    .fixedSize()
                    .position(x: squeezeAnchor.x, y: max(squeezeAnchor.y - 60, 80))
                    .onChange(of: tool) { showsSqueezePalette = false }
            }

            CanvasSidePanels(
                workspace: workspace,
                banner: $banner,
                onShowSource: showSource,
                onOpenSettings: { if let url = URL(string: "app-settings:") { openURL(url) } }
            )
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: ImportCoordinator.allowedTypes, allowsMultipleSelection: false) { result in
            Task { await handleImport(result) }
        }
        .sheet(item: $sheet) { sheet in
            sheetContent(sheet)
        }
        .onAppear { workspace.undoManager = undoManager }
        .onChange(of: undoManager) { workspace.undoManager = undoManager }
        .onChange(of: model.connection.state) { model.connectionChanged() }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            // Leaving the app ends capture; the audio stays with its own note.
            workspace.stopRecording()
            Task { await workspace.saveNow() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidCloseUndoGroup)) { _ in undoTick += 1 }
        .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange)) { _ in undoTick += 1 }
        .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange)) { _ in undoTick += 1 }
    }

    private var canUndo: Bool { _ = undoTick; return undoManager?.canUndo ?? false }
    private var canRedo: Bool { _ = undoTick; return undoManager?.canRedo ?? false }

    private func undo() { undoManager?.undo(); undoTick += 1 }
    private func redo() { undoManager?.redo(); undoTick += 1 }

    private var chromeActions: CanvasChrome.Actions {
        CanvasChrome.Actions(
            showCanvases: { sheet = .canvases },
            pickThread: { sheet = .threadPicker },
            importFile: { isImporting = true },
            pull: pull,
            showNotes: { sheet = .notes },
            showHistory: { sheet = .history },
            showSettings: { sheet = .settings },
            addRegion: { sheet = .addRegion },
            openFeedback: { sheet = .feedback(initialSelection: nil) },
            undo: undo,
            redo: redo,
            zoomIn: { zoom(by: 1.25) },
            zoomOut: { zoom(by: 0.8) },
            fitAll: fitAll
        )
    }

    @ViewBuilder
    private func sheetContent(_ sheet: CanvasSheet) -> some View {
        switch sheet {
        case .canvases:
            CanvasListSheet(workspace: workspace, connection: model.connection)
        case .settings:
            SettingsView(model: model)
        case .feedback(let selection):
            if let canvasId = workspace.currentCanvasId {
                FeedbackPreviewSheet(workspace: workspace, canvasId: canvasId, initialSelection: selection) { self.sheet = nil }
            }
        case .history:
            if let canvasId = workspace.currentCanvasId {
                DraftsAndHistoryView(workspace: workspace, canvasId: canvasId) { ids in
                    self.sheet = .feedback(initialSelection: ids)
                }
            }
        case .notes:
            NavigationStack {
                NotesListView(workspace: workspace) { noteId in
                    self.sheet = nil
                    showSource(noteId)
                }
                .navigationTitle("Comments")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { self.sheet = nil }
                    }
                }
            }
        case .addRegion:
            AddRegionSheet(workspace: workspace) { self.sheet = nil }
        case .threadPicker:
            ThreadBindingSheet(workspace: workspace, connection: model.connection)
        case .importTarget(let pending):
            ImportTargetSheet(workspace: workspace, pending: pending) { target in
                self.sheet = nil
                Task { await finishImport(pending, target: target) }
            }
        }
    }

    // MARK: - Camera

    private func zoom(by factor: Double) {
        guard let canvas = workspace.currentCanvas else { return }
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        workspace.updateCamera(CanvasFraming.zoomed(canvas.camera, by: factor, around: center), canvasId: canvas.id)
    }

    private func fitAll() {
        guard let canvas = workspace.currentCanvas, viewSize != .zero else { return }
        let camera = CanvasFraming.fitAll(canvas: canvas, viewSize: viewSize, insets: EdgeInsets(top: 96, leading: 24, bottom: 110, trailing: 24))
        workspace.updateCamera(camera, canvasId: canvas.id)
    }

    /// Show Source on Canvas: select the note's own version and frame it.
    private func showSource(_ noteId: UUID) {
        guard let canvas = workspace.currentCanvas, let note = canvas.notes.first(where: { $0.id == noteId }),
              let snapshot = canvas.snapshots.first(where: { $0.id == note.snapshotId }) else { return }
        let lane = LaneKey(screenId: snapshot.screenId, proposalId: snapshot.role == .baseline ? nil : snapshot.proposalId)
        workspace.selectVersion(snapshot.id, lane: lane)
        workspace.focusedNoteId = noteId
        guard let updated = workspace.currentCanvas,
              let camera = CanvasFraming.frame(snapshotId: snapshot.id, rect: note.shape.bounds, in: updated, viewSize: viewSize,
                                               insets: EdgeInsets(top: 96, leading: 24, bottom: 110, trailing: 400)) else { return }
        workspace.updateCamera(camera, canvasId: updated.id)
    }

    // MARK: - Import and pull

    private func handleImport(_ result: Result<[URL], any Error>) async {
        guard case .success(let urls) = result, let url = urls.first else { return }
        switch await importer.read(url) {
        case .success(let pending):
            if workspace.currentCanvas?.screens.isEmpty ?? true {
                await finishImport(pending, target: .newScreen(title: pending.suggestedTitle))
            } else {
                sheet = .importTarget(pending)
            }
        case .failure(let error):
            banner = CanvasBanner(message: error.message, isError: true)
        }
    }

    private func finishImport(_ pending: PendingImport, target: Workspace.ImportTarget) async {
        do {
            let snapshot = try importer.store(pending, target: target, in: workspace)
            banner = CanvasBanner(message: "Added \(snapshot.versionLabel) of \(pending.suggestedTitle)", isError: false)
            if workspace.currentCanvas?.snapshots.count == 1 { fitAll() }
        } catch {
            banner = CanvasBanner(message: ImportFailure(error).message, isError: true)
        }
    }

    private func pull() {
        guard let canvasId = workspace.currentCanvasId, !isPulling else { return }
        isPulling = true
        Task {
            let report = await workspace.pull(canvasId: canvasId, captureHTML: HTMLCaptureAdapter.capture)
            isPulling = false
            banner = CanvasBanner(pull: report)
            if report.importedSnapshots > 0 { fitAll() }
        }
    }
}
