#if canImport(UIKit)
import DrawspeakCore
import HTMLKit
import SwiftUI

/// One snapshot on the canvas, in world space: an image, or an HTML version
/// shown as its capture with the live document on top when it is close
/// enough to matter.
struct SnapshotCard: View {
    let slot: LaneSlot
    let workspace: Workspace
    let showsLiveHTML: Bool
    let imageMaxPixel: Int
    let inspector: DOMInspector?
    let accessibilityText: String
    let commentCount: Int
    let actions: CardActions
    var allowsInteraction = false

    @Environment(\.colorScheme) private var colorScheme

    @State private var isMissing = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let snapshot = slot.snapshot {
                if isMissing {
                    MissingSourceCard(snapshot: snapshot)
                } else {
                    if let capture = snapshot.image {
                        SnapshotImage(url: workspace.blobs.url(for: capture), maxPixelSize: imageMaxPixel, onFailure: markMissing)
                    }
                    if snapshot.kind == .html, showsLiveHTML, let source = snapshot.html, let inspector {
                        LiveHTMLLayer(
                            source: source,
                            blobs: workspace.blobs,
                            policy: snapshot.renderPolicy ?? .staticNoScript,
                            viewport: snapshot.viewport,
                            inspector: inspector,
                            width: slot.frame.width,
                            allowsInteraction: allowsInteraction,
                            snapshot: snapshot,
                            workspace: workspace,
                            canvasId: workspace.currentCanvasId
                        )
                        .id("\(snapshot.id)-\(allowsInteraction)")
                    }
                }
            } else {
                ContentUnavailableView("No version yet", systemImage: "square.dashed")
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .frame(width: slot.frame.width, height: slot.frame.height)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.cardCornerRadius))
        .clipShape(.rect(cornerRadius: Theme.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .strokeBorder(Color(uiColor: .separator).opacity(colorScheme == .dark ? 1 : 0), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, y: 2)
        .allowsHitTesting(allowsInteraction)
        .accessibilityElement(children: allowsInteraction ? .contain : .ignore)
        .accessibilityLabel(isMissing ? "\(accessibilityText). Missing \(slot.snapshot?.kind == .html ? "HTML" : "image") source: \(slot.snapshot?.title ?? "unknown file")" : accessibilityText)
        .accessibilityActions {
            if let snapshot = slot.snapshot, !isMissing, !allowsInteraction {
                if let addRegion = actions.addRegion {
                    Button("Add Region…") { addRegion(snapshot.id) }
                }
                if snapshot.kind == .html {
                    Button("Select Component…") { actions.selectComponent(slot.id) }
                }
            }
            if let snapshot = slot.snapshot, commentCount > 0 {
                Button("Show Comments") { actions.showComments(snapshot.id) }
            }
        }
        .offset(x: slot.frame.minX, y: slot.frame.minY)
        .onChange(of: workspace.currentCanvas, initial: true) { checkSource() }
        .onChange(of: slot.snapshot?.id) { checkSource() }
    }

    private func checkSource() {
        guard let snapshot = slot.snapshot else { return }
        isMissing = snapshot.sourceBlob.map { !workspace.blobs.exists($0) } ?? true
    }

    private func markMissing() {
        checkSource()
    }
}
#endif
