import CanvasKit
import DrawspeakCore
import NotesKit
import PhotosUI
import SwiftUI

/// The current canvas with the native toolbar and every presentation that
/// belongs to the canvas.
struct CanvasDetail: View {
    let model: AppModel
    let workspace: Workspace
    let controller: CanvasController

    @Environment(\.undoManager) private var undoManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppPreferences.drawWithFinger) private var drawWithFinger = false

    private var usesPanel: Bool { horizontalSizeClass != .compact }

    /// Only the compact layout presents Comments through `.inspector` (as a sheet).
    private var compactInspector: Binding<Bool> {
        Binding(get: { controller.showsInspector && !usesPanel }, set: { controller.showsInspector = $0 })
    }

    var body: some View {
        @Bindable var controller = controller
        CanvasStage(workspace: workspace, controller: controller, drawWithFinger: drawWithFinger)
            .navigationTitle($controller.canvasTitle)
            .navigationSubtitle(subtitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar { CanvasToolbar(workspace: workspace, controller: controller, isRegularWidth: horizontalSizeClass == .regular) }
            // Regular width: a glass panel over the full-width canvas, below the toolbar so Comments
            // and Send stay reachable. Compact width: the inspector presents as a sheet.
            .overlay(alignment: .trailing) {
                if controller.showsInspector && usesPanel {
                    CommentsPanel(workspace: workspace, controller: controller)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: controller.showsInspector)
            .inspector(isPresented: compactInspector) {
                // Built only while shown: a closed inspector's toolbar items would join the canvas toolbar.
                if compactInspector.wrappedValue {
                    CommentsColumn(workspace: workspace, controller: controller)
                }
            }
            .onChange(of: horizontalSizeClass, initial: true) { controller.usesInspectorPanel = usesPanel }
            .fileImporter(isPresented: $controller.showsImporter, allowedContentTypes: ImportCoordinator.allowedTypes,
                          allowsMultipleSelection: true, onCompletion: importFile)
            .photosPicker(isPresented: $controller.showsPhotoPicker, selection: $controller.selectedPhotos,
                          maxSelectionCount: CanvasController.maxImportCount, selectionBehavior: .ordered,
                          matching: .images, preferredItemEncoding: .current)
            .onChange(of: controller.selectedPhotos) { _, photos in
                guard !photos.isEmpty else { return }
                Task { await controller.handlePhotos(photos) }
            }
            .sheet(item: $controller.sheet, onDismiss: controller.sheetDismissed) { sheet in
                CanvasSheetContent(sheet: sheet, model: model, workspace: workspace, controller: controller)
            }
            .modifier(CanvasAlerts(controller: controller))
            .onAppear(perform: setUp)
            .onChange(of: undoManager) { workspace.undoManager = undoManager }
            .onChange(of: model.connection.state) { model.connectionChanged() }
            .onChange(of: workspace.focusedNoteId) { _, noteId in controller.focusedNoteChanged(noteId) }
            // Select mode belongs to the open Comments list; pins act normally again once it closes.
            .onChange(of: controller.showsInspector) { _, shown in if !shown { workspace.commentSelection = nil } }
            .onChange(of: workspace.lastSaveError) { _, message in controller.saveFailed(message) }
            .onChange(of: scenePhase) { _, phase in scenePhaseChanged(phase) }
            .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidCloseUndoGroup)) { _ in controller.undoStackChanged() }
            .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange)) { _ in controller.undoStackChanged() }
            .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange)) { _ in controller.undoStackChanged() }
    }

    private var subtitle: Text {
        if let thread = workspace.currentCanvas?.thread {
            Text(thread.displayName)
        } else {
            Text("No Thread")
        }
    }

    private func setUp() {
        workspace.undoManager = undoManager
        #if DEBUG
        controller.applyDebugLaunch()
        #endif
    }

    private func importFile(_ result: Result<[URL], any Error>) {
        Task { await controller.handleImport(result) }
    }

    /// Leaving the app ends capture; the audio stays with its own note.
    private func scenePhaseChanged(_ phase: ScenePhase) {
        guard phase != .active else { return }
        workspace.stopRecording()
        Task { await workspace.saveNow() }
    }
}
