#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Every note's mark over its snapshot, in world space, with a constant
/// on-screen stroke width. The focused note is drawn heavier.
struct MarksLayer: View {
    let marks: [PlacedMark]
    let focusedNoteId: UUID?
    /// Comments picked in Select mode; drawn as heavily as the focused one.
    var selectedNoteIds: Set<UUID> = []
    let camera: CanvasCamera

    @Environment(\.annotationStyle) private var annotationStyle
    var body: some View {
        let zoom = CGFloat(camera.zoom)
        let lineWidth = annotationStyle.lineWidth / zoom
        ZStack(alignment: .topLeading) {
            ForEach(marks) { mark in
                let isFocused = mark.noteId == focusedNoteId || selectedNoteIds.contains(mark.noteId)
                let width = isFocused ? lineWidth * 1.8 : lineWidth
                let path = MarkGeometry.path(for: mark.shape, in: mark.frame, headLength: 14 / zoom)
                path.stroke(Theme.annotationHalo, style: StrokeStyle(lineWidth: width + AnnotationStyle.haloExtra / zoom, lineCap: .round, lineJoin: .round))
                path
                    .stroke(
                        Theme.annotation,
                        style: StrokeStyle(lineWidth: isFocused ? lineWidth * 1.8 : lineWidth, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
