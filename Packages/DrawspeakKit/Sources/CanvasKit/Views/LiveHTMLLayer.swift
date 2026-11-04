#if canImport(UIKit)
import DrawspeakCore
import HTMLKit
import SwiftUI

/// The live, non-interactive HTML of a card, rendered at the snapshot's
/// viewport and scaled to the lane width. Hidden until the document loads,
/// so the capture image underneath shows meanwhile.
struct LiveHTMLLayer: View {
    let source: BlobRef
    let blobs: BlobStore
    let policy: RenderPolicy
    let viewport: Viewport
    let inspector: DOMInspector
    let width: CGFloat

    @State private var html: Data?
    @State private var isLoaded = false

    var body: some View {
        let size = CGSize(width: CGFloat(max(viewport.width, 1)), height: CGFloat(max(viewport.height, 1)))
        ZStack(alignment: .topLeading) {
            if let html {
                HTMLSnapshotView(
                    html: html,
                    policy: policy,
                    viewport: viewport,
                    inspector: inspector,
                    allowsInteraction: false,
                    onLoad: markLoaded
                )
                .frame(width: size.width, height: size.height)
                .scaleEffect(width / size.width, anchor: .topLeading)
                .opacity(isLoaded ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: source.sha256) {
            html = await BlobLoader.data(for: source, in: blobs)
        }
    }

    private func markLoaded() {
        isLoaded = true
    }
}
#endif
