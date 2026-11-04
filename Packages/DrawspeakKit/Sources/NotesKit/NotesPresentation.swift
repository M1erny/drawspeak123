import Foundation
import DrawspeakCore

/// Labels describe the immutable source, not the lane's current selection.
enum NotesPresentation {
    static func sourceLabel(_ snapshot: Snapshot, in canvas: ReviewCanvas) -> String {
        let screen = canvas.screens.first { $0.id == snapshot.screenId }?.title ?? String(localized: "Screen", bundle: .module)
        let version = snapshot.proposalId.map { CanvasLayout.proposalTitle($0) + " · " + snapshot.versionLabel } ?? snapshot.versionLabel
        return String(localized: "\(screen) · \(version)", bundle: .module)
    }
    static func duration(_ seconds: TimeInterval) -> String {
        let value = seconds.isFinite ? max(0, seconds.rounded(.down)) : 0
        return Duration.seconds(value).formatted(.time(pattern: .minuteSecond))
    }
}
