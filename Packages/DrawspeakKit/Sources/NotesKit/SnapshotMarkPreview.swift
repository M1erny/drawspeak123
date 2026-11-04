import SwiftUI
import ImageIO
import DrawspeakCore

/// ImageIO supports local content-addressed files without UIKit or URLSession's file URL limitations.
struct SnapshotMarkPreview: View {
    let workspace: Workspace
    let snapshot: Snapshot
    let shape: AnnotationShape
    var displayNumber: Int?
    var croppedToMark = false
    var maximumHeight: CGFloat = 260
    @State private var availableWidth: CGFloat = 300
    @State private var croppedImage: CGImage?

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

    var body: some View {
        GeometryReader { geometry in
            let inset = NotesMetrics.previewInset
            let width = max(1, geometry.size.width - inset * 2)
            let height = max(1, geometry.size.height - inset * 2)
            let fittedWidth = min(width, height * previewAspect)
            ZStack {
                Rectangle().fill(Theme.surface)
                if let croppedImage {
                    Image(decorative: croppedImage, scale: 1).resizable()
                } else {
                    Label { Text("Preview Unavailable", bundle: .module) } icon: { Image(systemName: "photo") }.font(.caption)
                }
                AnnotationPreviewShape(annotation: shape, crop: crop)
                    .stroke(Theme.annotation, lineWidth: Theme.markLineWidth)
                if let displayNumber {
                    PinBadge(number: displayNumber)
                        .position(x: min(max((shape.bounds.x - crop.x) / crop.width * fittedWidth, Theme.pinSize), fittedWidth - Theme.pinSize),
                                  y: min(max((shape.bounds.y - crop.y) / crop.height * fittedWidth / previewAspect, Theme.pinSize), fittedWidth / previewAspect - Theme.pinSize))
                }
            }
            .frame(width: fittedWidth, height: fittedWidth / previewAspect)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: min(maximumHeight, max(64, (availableWidth - 32) / previewAspect + 32)))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: max(0, Theme.paletteCornerRadius - 16)))
        .accessibilityLabel(Text("Screen with marked area", bundle: .module))
        .task(id: PreviewImageKey(url: snapshot.image.map { workspace.blobs.url(for: $0) }, crop: crop)) {
            await loadPreview()
        }
    }

    private func loadPreview() async {
        let key = PreviewImageKey(url: snapshot.image.map { workspace.blobs.url(for: $0) }, crop: crop)
        let result = await PreviewImageLoader.load(key)
        guard !Task.isCancelled else { return }
        croppedImage = result
    }

}

#Preview {
    let workspace = NotesPreview.workspace()
    SnapshotMarkPreview(workspace: workspace, snapshot: workspace.currentCanvas!.snapshots[0], shape: workspace.currentCanvas!.notes[0].shape)
}
