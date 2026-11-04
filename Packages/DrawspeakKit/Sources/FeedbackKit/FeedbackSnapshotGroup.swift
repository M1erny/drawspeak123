import SwiftUI
import DrawspeakCore

struct FeedbackSnapshotGroup: View {
    let group: FeedbackPreviewGroup
    @Bindable var model: FeedbackPreviewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var thumbnail: CGImage?
    @State private var renderError: String?
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        let horizontal = availableWidth >= FeedbackLayout.horizontalThreshold && !dynamicTypeSize.isAccessibilitySize
        let layout = horizontal ? AnyLayout(HStackLayout(alignment: .top, spacing: FeedbackLayout.spacing))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: FeedbackLayout.spacing))
        layout {
            FeedbackThumbnail(image: thumbnail, error: renderError)
                .frame(maxWidth: horizontal ? FeedbackLayout.thumbnailWidth : .infinity)
            VStack(alignment: .leading, spacing: FeedbackLayout.spacing) {
                ForEach(group.notes) { note in
                    FeedbackNoteRow(note: note, reason: model.reason(for: note), displayNumber: model.displayNumber(for: note), selection: $model.selection)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .task(id: group) { await renderThumbnail() }
    }

    private func renderThumbnail() async {
        thumbnail = nil
        renderError = nil
        guard let snapshot = group.snapshot else {
            renderError = String(localized: "Screen missing", bundle: .module)
            return
        }
        do {
            let png = try await CompositeRenderer.render(snapshot: snapshot, items: group.items, blobs: model.workspace.blobs, maxLongSide: 900, style: model.annotationStyle)
            let decoded = try await FeedbackImageWorker.decode(png)
            try Task.checkCancellation()
            thumbnail = decoded
        } catch {
            if !Task.isCancelled { renderError = error.localizedDescription }
        }
    }
}
