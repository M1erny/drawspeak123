import SwiftUI
import DrawspeakCore

struct AddRegionContent: View {
    let workspace: Workspace
    @Binding var snapshotId: String
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var x = 10.0
    @State private var y = 10.0
    @State private var width = 40.0
    @State private var height = 30.0
    @State private var oval = false

    private var shape: AnnotationShape {
        let rect = NRect(x: x / 100, y: y / 100, width: width / 100, height: height / 100)
        return oval ? .ellipse(rect) : .region(rect)
    }
    private var fitsSnapshot: Bool { shape.isValid && x + width <= 100 && y + height <= 100 }
    private var validSource: Bool { workspace.currentCanvas?.snapshots.contains { $0.id == snapshotId } == true }

    var body: some View {
        NavigationStack {
            Form {
                if let canvas = workspace.currentCanvas, !canvas.snapshots.isEmpty {
                    AddRegionSourcePicker(canvas: canvas, snapshotId: $snapshotId)
                    Section {
                        AddRegionControls(x: $x, y: $y, width: $width, height: $height, oval: $oval)
                        if !fitsSnapshot {
                            Text("Keep the area inside the screen.", bundle: .module).font(.footnote)
                        }
                    } header: { Text("Position", bundle: .module) }
                    if let snapshot = canvas.snapshots.first(where: { $0.id == snapshotId }) {
                        Section {
                            SnapshotMarkPreview(workspace: workspace, snapshot: snapshot, shape: shape, maximumHeight: NotesMetrics.previewHeight)
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label { Text("No Screens", bundle: .module) } icon: { Image(systemName: "photo") }
                    }
                }
            }
            .navigationTitle(Text("Add Region", bundle: .module))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: close)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: addRegion) { Text("Add", bundle: .module) }
                        .disabled(!fitsSnapshot || !validSource)
                }
            }
            .tint(.primary)
        }
    }

    private func close() { dismiss() }
    private func addRegion() {
        guard workspace.addNote(snapshotId: snapshotId, shape: shape) != nil else { return }
        onDone()
        dismiss()
    }
}
