#if canImport(UIKit)
import DrawspeakCore
import HTMLKit
import SwiftUI

/// The live HTML of a card, interactive only while trying the prototype at its
/// viewport and scaled to the lane width. Hidden until the document loads,
/// so the capture image underneath shows meanwhile.
struct LiveHTMLLayer: View {
    let source: BlobRef
    let blobs: BlobStore
    let policy: RenderPolicy
    let viewport: Viewport
    let inspector: DOMInspector
    let width: CGFloat
    let allowsInteraction: Bool
    let snapshot: Snapshot
    let workspace: Workspace
    let canvasId: UUID?

    @State private var didAttemptCapture = false

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
                    allowsInteraction: allowsInteraction,
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
        guard !didAttemptCapture, workspace.needsCapture(snapshot), let html, let canvasId else { return }
        didAttemptCapture = true
        Task {
            guard let capture = try? await HTMLCapture.capture(html: html, policy: policy, viewport: viewport) else { return }
            workspace.attachCapture(capture.pngData, pixelSize: (capture.pixelWidth, capture.pixelHeight), to: snapshot.id, canvasId: canvasId)
        }
    }
}
#endif
