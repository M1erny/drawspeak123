import DrawspeakCore
import Foundation

/// Package-localized labels; imported titles and DOM labels remain verbatim.
nonisolated enum CanvasLabels {
    static func versionTitle(of snapshot: Snapshot, in lane: Lane) -> String {
        let number = snapshot.role == .proposal && !lane.key.isNow
            ? snapshot.iteration : (lane.versions.firstIndex { $0.id == snapshot.id } ?? 0) + 1
        return String(localized: "Version \(number)", bundle: .module, comment: "Version number within a lane.")
    }
    static func card(lane: Lane, screenTitle: String, commentCount: Int) -> String {
        var parts = [lane.key.isNow ? String(localized: "Now", bundle: .module) : lane.title]
        if let snapshot = lane.selected { parts.append(versionTitle(of: snapshot, in: lane)) }
        parts.append(String(localized: "\(screenTitle) screen", bundle: .module, comment: "User-assigned screen title."))
        parts.append(String(AttributedString(localized: "^[\(commentCount) comment](inflect: true)", bundle: .module, comment: "Comments on this version.").characters))
        return parts.formatted(.list(type: .and))
    }
    static func pin(ordinal: Int, text: String, shape: AnnotationShape) -> String {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else {
            return String(localized: "Comment \(ordinal): No Text", bundle: .module, comment: "Number of an empty comment pin.")
        }
        let summary = words.prefix(8).joined(separator: " ") + (words.count > 8 ? "…" : "")
        return String(localized: "Comment \(ordinal): \(summary)", bundle: .module, comment: "Comment number and abbreviated user text.")
    }
    static func componentChip(label: String, depth: Int, chainCount: Int) -> String { label }
    static func depthTitle(depth: Int, label: String) -> String { label }
    static func layerTitle(index: Int, label: String) -> String { label }
}
