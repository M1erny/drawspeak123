import Foundation
import DrawspeakCore

struct ThreadStatusGroup: Identifiable, Equatable {
    enum Status: String, CaseIterable {
        case running, waiting, recent, stopped, older

        var title: String {
            switch self {
            case .running: String(localized: "Running", bundle: .module)
            case .waiting: String(localized: "Waiting", bundle: .module)
            case .recent: String(localized: "Recent", bundle: .module)
            case .stopped: String(localized: "Stopped", bundle: .module)
            case .older: String(localized: "Older", bundle: .module)
            }
        }

        static func classify(_ thread: ThreadSummary, now: Date) -> Self {
            switch thread.status {
            case "running", "starting", "preparing", "queued": .running
            case "waiting": .waiting
            case "interrupted", "failed", "cancelled", "rolled_back": .stopped
            case "completed": (thread.updatedAt ?? .distantPast) >= now.addingTimeInterval(-7 * 86_400) ? .recent : .older
            default: .recent
            }
        }
    }
    let id: Status
    var title: String { id.title }
    let threads: [ThreadSummary]
}
