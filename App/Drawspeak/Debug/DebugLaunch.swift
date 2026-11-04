#if DEBUG
import CanvasKit
import DrawspeakCore
import Foundation

/// Launch arguments for simulator screenshots: `-DrawspeakOpen <state>`.
@MainActor
enum DebugLaunch {
    static func apply(workspace: Workspace, sheet: inout CanvasSheet?, tool: inout CanvasTool) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-DrawspeakOpen"), index + 1 < arguments.count else { return }
        switch arguments[index + 1] {
        case "feedback": sheet = .feedback(initialSelection: nil)
        case "settings": sheet = .settings
        case "history": sheet = .history
        case "notes": sheet = .notes
        case "addRegion": sheet = .addRegion
        case "threads": sheet = .threadPicker
        case "canvases": sheet = .canvases
        case "inspector": workspace.focusedNoteId = workspace.currentCanvas?.notes.first?.id
        case "component": tool = .component
        default: break
        }
    }
}
#endif
