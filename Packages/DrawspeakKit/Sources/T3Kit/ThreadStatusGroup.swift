import Foundation
import DrawspeakCore

/// Sections of the thread picker, in the same order and with the same rules as
/// the T3 Code sidebar: snoozed and settled threads have their own shelves,
/// threads where the agent is running are Working, everything else needs attention.
struct ThreadStatusGroup: Identifiable, Equatable {
    enum Status: String, CaseIterable {
        case needsAttention, working, snoozed, settled

        var title: String {
            switch self {
            case .needsAttention: String(localized: "Needs Attention", bundle: .module)
            case .working: String(localized: "Working", bundle: .module)
            case .snoozed: String(localized: "Snoozed", bundle: .module)
            case .settled: String(localized: "Settled", bundle: .module)
            }
        }

        static let workingStatuses: Set<String> = ["running", "starting", "preparing", "queued"]

        static func classify(_ thread: ThreadSummary, now: Date) -> Self {
            if thread.snoozed { return .snoozed }
            if thread.settled { return .settled }
            if workingStatuses.contains(thread.status ?? "") { return .working }
            return .needsAttention
        }
    }
    let id: Status
    var title: String { id.title }
    let threads: [ThreadSummary]
}
