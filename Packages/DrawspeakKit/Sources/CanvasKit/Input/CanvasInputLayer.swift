#if canImport(UIKit)
import SwiftUI

/// Hosts the UIKit input surface. Tool settings reach it through
/// `CanvasInteraction`, which `CanvasView` updates outside view updates.
struct CanvasInputLayer: UIViewRepresentable {
    let interaction: CanvasInteraction

    func makeUIView(context: Context) -> CanvasInputSurface {
        CanvasInputSurface(interaction: interaction)
    }

    func updateUIView(_ surface: CanvasInputSurface, context: Context) {}
}
#endif
