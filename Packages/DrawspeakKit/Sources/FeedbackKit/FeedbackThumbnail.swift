import SwiftUI

struct FeedbackThumbnail: View {
    let image: CGImage?
    let error: String?
    var body: some View {
        Group {
            if let image { Image(decorative: image, scale: 1).resizable().scaledToFit() }
            else if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
            else { ProgressView() }
        }
        .frame(maxHeight: FeedbackLayout.thumbnailHeight)
        .accessibilityHidden(true)
    }
}
