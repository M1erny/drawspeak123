import Foundation
import DrawspeakCore

struct CommentGroup: Identifiable {
    let id: String
    let title: String
    let notes: [Note]

    static func make(_ canvas: ReviewCanvas?, notes: [Note]) -> [Self] {
        guard let canvas else { return [] }
        let snapshots = Dictionary(canvas.snapshots.map { ($0.id, $0.screenId) }, uniquingKeysWith: { first, _ in first })
        let grouped = Dictionary(grouping: notes) { snapshots[$0.snapshotId] ?? "" }
        var result = canvas.screens.compactMap { screen -> Self? in
            guard let notes = grouped[screen.id], !notes.isEmpty else { return nil }
            return Self(id: screen.id, title: screen.title, notes: notes.sorted { $0.ordinal < $1.ordinal })
        }
        let known = Set(canvas.screens.map(\.id))
        let missing = grouped.filter { !known.contains($0.key) }.values.flatMap { $0 }.sorted { $0.ordinal < $1.ordinal }
        if !missing.isEmpty {
            result.append(Self(id: "missing", title: String(localized: "File Missing", bundle: .module), notes: missing))
        }
        return result
    }
}
