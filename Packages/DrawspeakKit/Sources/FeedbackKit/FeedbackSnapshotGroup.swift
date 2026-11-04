import SwiftUI
import DrawspeakCore
import ImageIO

struct FeedbackSnapshotGroup: View {
    let snapshot: Snapshot?
    let title: String
    let notes: [Note]
    @Bindable var model: FeedbackPreviewModel
    @State private var thumbnail: CGImage?
    @State private var renderError: String?
    private var items: [BatchItem] { notes.filter { model.selection.contains($0.id) }.map(BatchItem.init(note:)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            if let thumbnail {
                Image(decorative: thumbnail, scale: 1).resizable().scaledToFit().frame(maxHeight: 300)
                    .accessibilityLabel("Annotated snapshot, \(items.count) selected comments")
            } else if let renderError { Text(renderError).font(.caption).foregroundStyle(.red) }
            else { ProgressView("Rendering snapshot…") }
            ForEach(notes) { note in
                FeedbackNoteRow(note: note, reason: model.reason(for: note), selection: $model.selection)
            }
        }
        .task(id: items) {
            thumbnail = nil; renderError = nil
            guard let snapshot else { renderError = "Snapshot is missing"; return }
            do {
                let png = try await CompositeRenderer.render(snapshot: snapshot, items: items, blobs: model.workspace.blobs, maxLongSide: 900)
                guard !Task.isCancelled else { return }
                thumbnail = CGImageSourceCreateWithData(png as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
            } catch { if !Task.isCancelled { renderError = error.localizedDescription } }
        }
    }
}
