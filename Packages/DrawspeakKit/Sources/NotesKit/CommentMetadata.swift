import SwiftUI
import DrawspeakCore

/// The version a comment is on, how it was made, and whether it was sent.
struct CommentMetadata: View {
    let workspace: Workspace
    let note: Note

    var body: some View {
        Text(parts.joined(separator: " · "))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var parts: [String] {
        var parts: [String] = []
        if let snapshot = workspace.currentCanvas?.snapshots.first(where: { $0.id == note.snapshotId }) {
            parts.append(CommentFilter.versionTitle(snapshot))
        }
        if note.domTarget != nil { parts.append(String(localized: "Component", bundle: .module)) }
        if !note.recordings.isEmpty { parts.append(String(localized: "Voice", bundle: .module)) }
        if let sent = note.lastSentRevision, sent == note.revision {
            parts.append(String(localized: "Sent", bundle: .module))
        } else if note.lastSentRevision != nil {
            parts.append(String(localized: "Edited after sending", bundle: .module))
        }
        return parts
    }
}
