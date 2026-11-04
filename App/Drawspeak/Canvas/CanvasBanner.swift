import DrawspeakCore
import Foundation

/// A short status message shown over the canvas (import, pull).
struct CanvasBanner: Equatable, Identifiable {
    let id = UUID()
    var message: String
    var details: [String] = []
    var isError: Bool

    init(message: String, details: [String] = [], isError: Bool) {
        self.message = message
        self.details = details
        self.isError = isError
    }

    init(pull report: Workspace.PullReport) {
        if report.importedSnapshots > 0 {
            message = "Added \(report.importedSnapshots) version\(report.importedSnapshots == 1 ? "" : "s") from the thread"
        } else if report.issues.isEmpty {
            message = "No new versions in the thread"
        } else {
            message = "Pull found problems"
        }
        details = Array(report.issues.prefix(4))
        isError = report.importedSnapshots == 0 && !report.issues.isEmpty
    }
}
