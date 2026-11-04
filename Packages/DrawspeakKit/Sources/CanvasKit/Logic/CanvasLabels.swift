import DrawspeakCore
import Foundation

/// Visible and VoiceOver text for canvas elements.
nonisolated enum CanvasLabels {
    /// "Iteration 2" for proposals; "Revision 3" for Now (its position in history).
    static func versionTitle(of snapshot: Snapshot, in lane: Lane) -> String {
        if snapshot.role == .proposal, !lane.key.isNow { return "Iteration \(snapshot.iteration)" }
        let index = lane.versions.firstIndex { $0.id == snapshot.id } ?? 0
        return "Revision \(index + 1)"
    }

    /// "Proposal A, Iteration 2, Checkout screen, 3 comments".
    static func card(lane: Lane, screenTitle: String, commentCount: Int) -> String {
        var parts = [lane.title]
        if let snapshot = lane.selected { parts.append(versionTitle(of: snapshot, in: lane)) }
        parts.append("\(screenTitle) screen")
        parts.append(commentCount == 1 ? "1 comment" : "\(commentCount) comments")
        return parts.joined(separator: ", ")
    }

    /// "Comment 3: The pay button looks disabled". Uses the mark kind until text exists.
    static func pin(ordinal: Int, text: String, shape: AnnotationShape) -> String {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return "Comment \(ordinal): \(shape.kindLabel), no text yet" }
        let summary = words.prefix(8).joined(separator: " ")
        return "Comment \(ordinal): \(summary)\(words.count > 8 ? "…" : "")"
    }

    /// "Pay Button · parent 1 of 4" near the Pencil tip.
    static func componentChip(label: String, depth: Int, chainCount: Int) -> String {
        let parents = chainCount - 1
        guard parents > 0 else { return label }
        guard depth > 0 else { return "\(label) · element, \(parents) \(parents == 1 ? "parent" : "parents")" }
        return "\(label) · parent \(depth) of \(parents)"
    }

    /// Row title in the hierarchy list.
    static func depthTitle(depth: Int, label: String) -> String {
        depth == 0 ? "Element: \(label)" : "Parent \(depth): \(label)"
    }

    /// Row title in the Layers picker.
    static func layerTitle(index: Int, label: String) -> String {
        index == 0 ? "Top layer: \(label)" : "Underneath \(index): \(label)"
    }
}
