#if DEBUG
import Foundation

/// States for `-DrawspeakOpen <state>` (scripts/sim-shots.sh).
enum DebugOpenState: String {
    case feedback, settings, history, comments, addRegion, threads, canvases, component

    init?(argument: String) {
        switch argument {
        case "inspector", "notes": self = .comments
        default: self.init(rawValue: argument)
        }
    }
}
#endif
