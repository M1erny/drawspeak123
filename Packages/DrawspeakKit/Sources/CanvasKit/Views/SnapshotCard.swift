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
                    ZStack(alignment: .topLeading) {
                        if let capture = snapshot.image {
                            SnapshotImage(url: workspace.blobs.url(for: capture), maxPixelSize: imageMaxPixel, size: slot.frame.size, onFailure: markMissing)
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
                    // Presentation only: stored captures and exported source colors stay intact.
                    // A plain dimming layer, not `.brightness`: a color filter renders the
                    // whole card offscreen, and a tall board zoomed in exceeds the GPU
                    // texture limit, so the image would vanish.
                    .overlay {
                        if colorScheme == .dark {
                            Color.black.opacity(0.10).allowsHitTesting(false)
                        }
                    }
                }
            } else {
                ContentUnavailableView(String(localized: "No Version", bundle: .module), systemImage: "square.dashed")
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .frame(width: slot.frame.width, height: slot.frame.height)
        .background(slot.snapshot?.kind == .image && !isMissing ? .clear : Theme.surface, in: .rect(cornerRadius: Theme.cardCornerRadius))
        .clipShape(.rect(cornerRadius: Theme.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .strokeBorder(colorScheme == .dark ? Theme.secondaryInk : .clear, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, y: 2)
        .allowsHitTesting(allowsInteraction)
        .accessibilityElement(children: allowsInteraction ? .contain : .ignore)
        .accessibilityLabel(isMissing ? String(localized: "\(accessibilityText). File Missing", bundle: .module, comment: "Description of the screen whose source file is missing.") : accessibilityText)
        .accessibilityActions {
            if let snapshot = slot.snapshot, !isMissing, !allowsInteraction {
                if let addRegion = actions.addRegion {
                    Button(String(localized: "Add Region…", bundle: .module)) { addRegion(snapshot.id) }
                }
                if snapshot.kind == .html {
                    Button(String(localized: "Select Component…", bundle: .module)) { actions.selectComponent(slot.id) }
                }
            }
            if let snapshot = slot.snapshot, commentCount > 0 {
                Button(String(localized: "Show Comments", bundle: .module)) { actions.showComments(snapshot.id) }
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
