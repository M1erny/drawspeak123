#if DEBUG
import Foundation

extension CanvasController {
    /// Opens the state requested by `-DrawspeakOpen`, once the toolbar exists.
    func applyDebugLaunch() {
        guard let state = DebugLaunch.requestedState else { return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            switch state {
            case .feedback: openFeedback()
            case .settings: showSettings()
            case .history: showHistory()
            case .comments:
                workspace.focusedNoteId = workspace.currentCanvas?.notes.first?.id
                showsInspector = true
            case .addRegion: addRegion()
            case .threads: chooseThread()
            case .component: tool = .component
            case .canvases: break
            }
        }
    }
}
#endif
