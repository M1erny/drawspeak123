import SwiftUI
import DrawspeakCore

public struct AddRegionSheet: View {
    private let workspace: Workspace
    private let onDone: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @State private var snapshotId = ""
    @State private var x = 10.0
    @State private var y = 10.0
    @State private var width = 40.0
    @State private var height = 30.0
    @State private var oval = false

    public init(workspace: Workspace, initialSnapshotId: String? = nil, onDone: @escaping () -> Void) {
        self.workspace = workspace
        self.onDone = onDone
        _snapshotId = State(initialValue: initialSnapshotId ?? "")
    }

    private var shape: AnnotationShape {
        let rect = NRect(x: x / 100, y: y / 100, width: width / 100, height: height / 100)
        return oval ? .ellipse(rect) : .region(rect)
    }

    private var fitsSnapshot: Bool { shape.isValid && x + width <= 100 && y + height <= 100 }

    private func sourcePicker(canvas: ReviewCanvas) -> some View {
        Section("Source") {
            Picker("Snapshot", selection: $snapshotId) {
                Text("Choose a snapshot").tag("")
                ForEach(canvas.snapshots) { snapshot in
                    Text(NotesPresentation.sourceLabel(snapshot, in: canvas) + " · " + snapshot.title)
                        .tag(snapshot.id)
                }
            }
        }
    }

    public var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                content.presentationSizing(.form)
            } else {
                content
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var content: some View {
        NavigationStack {
            Form {
                if let canvas = workspace.currentCanvas, !canvas.snapshots.isEmpty {
                    sourcePicker(canvas: canvas)
                    Section("Region in Percent") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 8) {
                            PercentControl(title: "X", value: $x)
                            PercentControl(title: "Y", value: $y)
                            PercentControl(title: "Width", value: $width)
                            PercentControl(title: "Height", value: $height)
                        }
                        Picker("Shape", selection: $oval) {
                            Text("Region").tag(false)
                            Text("Oval").tag(true)
                        }
                        if !fitsSnapshot { Text("Use a non-empty region within the snapshot bounds.").font(.footnote) }
                    }
                    if let snapshot = canvas.snapshots.first(where: { $0.id == snapshotId }) {
                        Section("Source Preview") {
                            SnapshotMarkPreview(workspace: workspace, snapshot: snapshot, shape: shape)
                                .frame(maxHeight: 260)
                        }
                    }
                } else {
                    ContentUnavailableView("No Snapshots", systemImage: "photo", description: Text("Import a snapshot before adding a region."))
                }
            }
            .navigationTitle("Add Region")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", systemImage: "plus") {
                        if workspace.addNote(snapshotId: snapshotId, shape: shape) != nil {
                            onDone()
                            dismiss()
                        }
                    }
                    .disabled(!fitsSnapshot || !(workspace.currentCanvas?.snapshots.contains { $0.id == snapshotId } ?? false))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .task { if snapshotId.isEmpty { snapshotId = workspace.currentCanvas?.snapshots.first?.id ?? "" } }
        }
    }
}

#Preview { AddRegionSheet(workspace: NotesPreview.workspace(), onDone: {}) }
