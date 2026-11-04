import SwiftUI
import DrawspeakCore

public struct AddRegionSheet: View {
    private let workspace: Workspace
    private let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var snapshotId = ""
    @State private var x = 10.0
    @State private var y = 10.0
    @State private var width = 40.0
    @State private var height = 30.0
    @State private var oval = false

    public init(workspace: Workspace, onDone: @escaping () -> Void) {
        self.workspace = workspace
        self.onDone = onDone
    }

    private var shape: AnnotationShape {
        let rect = NRect(x: x / 100, y: y / 100, width: width / 100, height: height / 100)
        return oval ? .ellipse(rect) : .region(rect)
    }

    private var fitsSnapshot: Bool { shape.isValid && x + width <= 100 && y + height <= 100 }

    public var body: some View {
        NavigationStack {
            Form {
                if let canvas = workspace.currentCanvas, !canvas.snapshots.isEmpty {
                    Section("Source") {
                        Picker("Snapshot", selection: $snapshotId) {
                            Text("Choose a snapshot").tag("")
                            ForEach(canvas.screens) { screen in
                                ForEach(CanvasLayout.lanes(in: canvas, screen: screen)) { lane in
                                    Section(screen.title + " · " + lane.title) {
                                        ForEach(lane.versions) { snapshot in
                                            Text(snapshot.versionLabel + " · " + snapshot.title).tag(snapshot.id)
                                        }
                                    }
                                }
                            }
                        }
                        if let snapshot = canvas.snapshots.first(where: { $0.id == snapshotId }) {
                            SnapshotMarkPreview(workspace: workspace, snapshot: snapshot, shape: shape)
                        }
                    }
                    Section("Region in Percent") {
                        PercentControl(title: "X", value: $x)
                        PercentControl(title: "Y", value: $y)
                        PercentControl(title: "Width", value: $width)
                        PercentControl(title: "Height", value: $height)
                        Picker("Shape", selection: $oval) {
                            Text("Region").tag(false)
                            Text("Oval").tag(true)
                        }
                        if !fitsSnapshot { Text("Use a non-empty region within the snapshot bounds.").font(.footnote) }
                    }
                    Section {
                        Button("Add Region", systemImage: "plus.rectangle") {
                            if workspace.addNote(snapshotId: snapshotId, shape: shape) != nil {
                                onDone()
                                dismiss()
                            }
                        }
                        .frame(minHeight: Theme.minTarget)
                        .disabled(!fitsSnapshot || !canvas.snapshots.contains { $0.id == snapshotId })
                    }
                } else {
                    ContentUnavailableView("No Snapshots", systemImage: "photo", description: Text("Import a snapshot before adding a region."))
                }
            }
            .navigationTitle("Add Region")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .task { if snapshotId.isEmpty { snapshotId = workspace.currentCanvas?.snapshots.first?.id ?? "" } }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview { AddRegionSheet(workspace: NotesPreview.workspace(), onDone: {}) }
