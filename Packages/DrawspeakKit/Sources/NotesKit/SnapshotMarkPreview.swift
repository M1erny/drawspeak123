import SwiftUI
import ImageIO
import DrawspeakCore

/// ImageIO supports local content-addressed files without UIKit or URLSession's file URL limitations.
struct SnapshotMarkPreview: View {
    let workspace: Workspace
    let snapshot: Snapshot
    let shape: AnnotationShape
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Theme.surface)
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFit()
            } else {
                Label("Snapshot Preview Unavailable", systemImage: "photo").font(.caption)
            }
            AnnotationPreviewShape(annotation: shape).stroke(Theme.annotation, lineWidth: Theme.markLineWidth)
        }
        .aspectRatio(snapshot.aspectRatio, contentMode: .fit)
        .clipShape(.rect(cornerRadius: Theme.cardCornerRadius))
        .accessibilityLabel("Original snapshot, \(shape.kindLabel.lowercased()) marked")
        .task(id: snapshot.image) {
            image = nil
            guard let blob = snapshot.image else { return }
            let url = workspace.blobs.url(for: blob)
            image = await Task.detached {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil as CGImage? }
                return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 900,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ] as CFDictionary)
            }.value
        }
    }
}

#Preview {
    let workspace = NotesPreview.workspace()
    SnapshotMarkPreview(workspace: workspace, snapshot: workspace.currentCanvas!.snapshots[0], shape: workspace.currentCanvas!.notes[0].shape)
}
