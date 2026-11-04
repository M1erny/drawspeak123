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

    @State private var isMissing = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let snapshot = slot.snapshot {
                if isMissing {
                    MissingSourceCard()
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
                            width: slot.frame.width
                        )
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
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isMissing ? "\(accessibilityText). Source file is missing" : accessibilityText)
        .accessibilityActions {
            if let snapshot = slot.snapshot, !isMissing {
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
        .task(id: slot.snapshot?.id) {
            checkSource()
        }
    }

    private func checkSource() {
        guard let snapshot = slot.snapshot else { return }
        isMissing = !workspace.isSourceAvailable(snapshot)
    }

    private func markMissing() {
        isMissing = true
    }
}
#endif
