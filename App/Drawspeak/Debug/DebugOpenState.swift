#if DEBUG
import Foundation

/// States for `-DrawspeakOpen <state>` (scripts/sim-shots.sh).
enum DebugOpenState: String {
    case feedback, settings, pairing, history, comments, addRegion, threads, canvases, component, importTarget

    init?(argument: String) {
        switch argument {
        case "inspector", "notes": self = .comments
        default: self.init(rawValue: argument)
        }
    }
}
#endif
