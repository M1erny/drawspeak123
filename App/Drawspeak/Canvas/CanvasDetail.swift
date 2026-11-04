import CanvasKit
import DrawspeakCore
import NotesKit
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
    @AppStorage(AppPreferences.drawWithFinger) private var drawWithFinger = false

    var body: some View {
        @Bindable var controller = controller
        CanvasStage(workspace: workspace, controller: controller, drawWithFinger: drawWithFinger)
            .navigationTitle($controller.canvasTitle)
            .navigationSubtitle(subtitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar { CanvasToolbar(workspace: workspace, controller: controller, isRegularWidth: horizontalSizeClass == .regular) }
            .fileImporter(isPresented: $controller.showsImporter, allowedContentTypes: ImportCoordinator.allowedTypes,
                          allowsMultipleSelection: false, onCompletion: importFile)
            .sheet(item: $controller.sheet, onDismiss: controller.sheetDismissed) { sheet in
                CanvasSheetContent(sheet: sheet, model: model, workspace: workspace, controller: controller)
            }
            .modifier(CanvasAlerts(controller: controller))
            .onAppear(perform: setUp)
            .onChange(of: undoManager) { workspace.undoManager = undoManager }
            .onChange(of: model.connection.state) { model.connectionChanged() }
            .onChange(of: workspace.focusedNoteId) { _, noteId in controller.focusedNoteChanged(noteId) }
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
