#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Every note's mark over its snapshot, in world space, with a constant
/// on-screen stroke width. The focused note is drawn heavier.
struct MarksLayer: View {
    let marks: [PlacedMark]
    let focusedNoteId: UUID?
    let camera: CanvasCamera

    var body: some View {
        let zoom = CGFloat(camera.zoom)
        let lineWidth = Theme.markLineWidth / zoom
        ZStack(alignment: .topLeading) {
            ForEach(marks) { mark in
                let isFocused = mark.noteId == focusedNoteId
                MarkGeometry.path(for: mark.shape, in: mark.frame, headLength: 14 / zoom)
                    .stroke(
                        Theme.annotation.opacity(isFocused || focusedNoteId == nil ? 1 : 0.75),
                        style: StrokeStyle(lineWidth: isFocused ? lineWidth * 1.8 : lineWidth, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
