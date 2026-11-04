#if canImport(UIKit)
import SwiftUI

/// A snapshot bitmap decoded off the main thread at the requested size. The
/// previous decode stays visible while a sharper one loads.
struct SnapshotImage: View {
    let url: URL
    let maxPixelSize: Int
    var onFailure: (() -> Void)?

    @State private var image: DecodedImage?

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image.cgImage, scale: 1)
                    .resizable()
                    .interpolation(.high)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: "\(url.lastPathComponent)#\(maxPixelSize)") {
            await load()
        }
    }

    private func load() async {
        if let decoded = await ImageCache.shared.image(at: url, maxPixelSize: maxPixelSize) {
            image = decoded
        } else if image == nil {
            onFailure?()
        }
    }
}
#endif
