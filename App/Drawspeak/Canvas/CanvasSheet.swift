import Foundation

/// Every sheet the canvas detail can present. One at a time.
enum CanvasSheet: Identifiable {
    case settings
    case history
    case addRegion(snapshotId: String?)
    case threadPicker(thenFeedback: Set<UUID>?)
    case importTarget(PendingImport)

    var id: String {
        switch self {
        case .settings: "settings"
        case .history: "history"
        case .addRegion: "addRegion"
        case .threadPicker: "threadPicker"
        case .importTarget(let pending): "import-\(pending.id)"
        }
    }
}
