import SwiftUI
import DrawspeakCore
import ImageIO

struct FeedbackSnapshotGroup: View {
    let snapshot: Snapshot?
    let title: String
    let notes: [Note]
    @Bindable var model: FeedbackPreviewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var thumbnail: CGImage?
    @State private var renderError: String?
    private var items: [BatchItem] { notes.filter { model.selection.contains($0.id) }.map(BatchItem.init(note:)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            let layout = sizeClass == .compact
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            layout {
                Group {
                    if let thumbnail {
                        Image(decorative: thumbnail, scale: 1).resizable().scaledToFit()
                            .frame(maxHeight: 200)
                    } else if let renderError { Text(renderError).font(.caption).foregroundStyle(.red) }
                    else { ProgressView("Rendering snapshot…") }
                }
                .frame(width: 200)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(notes) { note in
                        FeedbackNoteRow(note: note, reason: model.reason(for: note), selection: $model.selection)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
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
