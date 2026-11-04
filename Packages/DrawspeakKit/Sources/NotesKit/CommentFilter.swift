import Foundation
import DrawspeakCore

/// Inspector-only scope; choosing a filter never changes canvas selection.
enum CommentFilter: Hashable {
    case all
    case screen(String)
    case snapshot(String)

    func includes(_ note: Note, canvas: ReviewCanvas?) -> Bool {
        switch self {
        case .all: true
        case .screen(let id):
            canvas?.screens.contains { $0.id == id } == true &&
                canvas?.snapshots.contains { $0.id == note.snapshotId && $0.screenId == id } == true
        case .snapshot(let id): note.snapshotId == id && canvas?.snapshots.contains { $0.id == id } == true
        }
    }

    func title(in canvas: ReviewCanvas?) -> String {
        switch self {
        case .all: return String(localized: "All", bundle: .module)
        case .screen(let id): return canvas?.screens.first { $0.id == id }?.title ?? ""
        case .snapshot(let id):
            guard let snapshot = canvas?.snapshots.first(where: { $0.id == id }) else { return "" }
            let screen = canvas?.screens.first { $0.id == snapshot.screenId }?.title ?? ""
            return String(localized: "\(screen) › \(Self.versionTitle(snapshot))", bundle: .module)
        }
    }

    static func versionTitle(_ snapshot: Snapshot) -> String {
        if snapshot.role == .baseline { return String(localized: "Now", bundle: .module) }
        let proposal = CanvasLayout.proposalTitle(snapshot.proposalId ?? "?")
        return String(localized: "\(proposal) · Version \(snapshot.iteration)", bundle: .module)
    }
}
