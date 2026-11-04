import SwiftUI
import DrawspeakCore

struct AddRegionSourcePicker: View {
    let canvas: ReviewCanvas
    @Binding var snapshotId: String
    var body: some View {
        Picker(selection: $snapshotId) {
            Text("Choose", bundle: .module).tag("")
            ForEach(canvas.snapshots) { snapshot in
                Text(NotesPresentation.sourceLabel(snapshot, in: canvas)).tag(snapshot.id)
            }
        } label: { Text("Screen", bundle: .module) }
    }
}
