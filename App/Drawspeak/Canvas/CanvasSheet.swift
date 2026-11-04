import Foundation

/// Every sheet the canvas screen can present. One at a time.
enum CanvasSheet: Identifiable {
    case canvases
    case settings
    case feedback(initialSelection: Set<UUID>?)
    case history
    case notes
    case addRegion
    case threadPicker
    case importTarget(PendingImport)

    var id: String {
        switch self {
        case .canvases: "canvases"
        case .settings: "settings"
        case .feedback: "feedback"
        case .history: "history"
        case .notes: "notes"
        case .addRegion: "addRegion"
        case .threadPicker: "threadPicker"
        case .importTarget(let pending): "import-\(pending.id)"
        }
    }
}
