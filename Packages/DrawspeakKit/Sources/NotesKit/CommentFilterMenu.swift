import SwiftUI
import DrawspeakCore

struct CommentFilterMenu: View {
    let canvas: ReviewCanvas?
    let notes: [Note]
    @Binding var selection: CommentFilter

    private var snapshotIDs: Set<String> { Set(notes.map(\.snapshotId)) }
    private var screens: [Screen] {
        canvas?.screens.filter { screen in
            canvas?.snapshots.contains { $0.screenId == screen.id && snapshotIDs.contains($0.id) } == true
        } ?? []
    }

    var body: some View {
        Menu {
            Picker(selection: $selection) {
                Text("All", bundle: .module).tag(CommentFilter.all)
            } label: { Text("Filter Comments", bundle: .module) }
            ForEach(screens) { screen in
                Menu {
                    Picker(selection: $selection) {
                        Text(verbatim: screen.title).tag(CommentFilter.screen(screen.id))
                        ForEach(canvas?.snapshots.filter { $0.screenId == screen.id && snapshotIDs.contains($0.id) } ?? []) { snapshot in
                            Text(verbatim: CommentFilter.versionTitle(snapshot)).tag(CommentFilter.snapshot(snapshot.id))
                        }
                    } label: { Text(verbatim: screen.title) }
                } label: { Text(verbatim: screen.title) }
            }
        } label: {
            Label {
                Text(verbatim: selection.title(in: canvas))
            } icon: { Image(systemName: "line.3.horizontal.decrease") }
        }
        .labelStyle(.titleAndIcon)
        .accessibilityLabel(Text("Filter Comments", bundle: .module))
        .accessibilityValue(selection.title(in: canvas))
    }
}
