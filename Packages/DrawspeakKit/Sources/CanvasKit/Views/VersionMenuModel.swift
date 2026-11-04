#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

@Observable
final class VersionMenuModel {
    private(set) var entries: [VersionMenuEntry] = []
    private(set) var addressedComments = ""
    private(set) var canPromote = false
    func update(lane: Lane, canvas: ReviewCanvas?) {
        entries = lane.versions.reversed().map { snapshot in
            let returned = canvas.map { CanvasLayout.isUnpromotedBaseline(snapshot, in: $0) } ?? false
            return VersionMenuEntry(id: snapshot.id,
                title: returned ? String(localized: "New from Agent", bundle: .module) : CanvasLabels.versionTitle(of: snapshot, in: lane),
                capturedAt: snapshot.capturedAt, summary: snapshot.changeSummary)
        }
        guard let selected = lane.selected else { addressedComments = ""; canPromote = false; return }
        let ids = Set(selected.addressedNoteIds.compactMap(UUID.init(uuidString:)))
        addressedComments = (canvas?.notes ?? []).filter { ids.contains($0.id) }.map(\.ordinal).sorted()
            .map { $0.formatted() }.formatted(.list(type: .and))
        canPromote = !lane.key.isNow || (canvas.map { CanvasLayout.isUnpromotedBaseline(selected, in: $0) } ?? false)
    }
}
#endif
