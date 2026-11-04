import SwiftUI
import ImageIO
import DrawspeakCore

/// ImageIO supports local content-addressed files without UIKit or URLSession's file URL limitations.
struct SnapshotMarkPreview: View {
    let workspace: Workspace
    let snapshot: Snapshot
    let shape: AnnotationShape
    var croppedToMark = false
    var maximumHeight: CGFloat = 260
    @State private var availableWidth: CGFloat = 300
    @State private var image: CGImage?

    private var crop: NRect {
        guard croppedToMark else { return NRect(x: 0, y: 0, width: 1, height: 1) }
        let bounds = shape.bounds.clamped()
        let dx = max(bounds.width * 0.3, 0.03)
        let dy = max(bounds.height * 0.3, 0.03)
        let x = max(0, bounds.x - dx), y = max(0, bounds.y - dy)
        return NRect(x: x, y: y, width: min(1, bounds.x + bounds.width + dx) - x,
                     height: min(1, bounds.y + bounds.height + dy) - y)
    }

    private var previewAspect: CGFloat { snapshot.aspectRatio * crop.width / crop.height }

    private var croppedImage: CGImage? {
        guard let image else { return nil }
        let rect = CGRect(x: crop.x * Double(image.width), y: crop.y * Double(image.height),
                          width: crop.width * Double(image.width), height: crop.height * Double(image.height))
        return image.cropping(to: rect)
    }

    var body: some View {
        GeometryReader { geometry in
            let inset: CGFloat = 16
            let width = max(1, geometry.size.width - inset * 2)
            let height = max(1, geometry.size.height - inset * 2)
            let fittedWidth = min(width, height * previewAspect)
            ZStack {
                Rectangle().fill(Theme.surface)
                if let croppedImage {
                    Image(decorative: croppedImage, scale: 1).resizable()
                } else {
                    Label("Snapshot Preview Unavailable", systemImage: "photo").font(.caption)
                }
                AnnotationPreviewShape(annotation: shape, crop: crop)
                    .stroke(Theme.annotation, lineWidth: Theme.markLineWidth)
            }
            .frame(width: fittedWidth, height: fittedWidth / previewAspect)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: min(maximumHeight, max(64, (availableWidth - 32) / previewAspect + 32)))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: max(0, Theme.paletteCornerRadius - 16)))
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
