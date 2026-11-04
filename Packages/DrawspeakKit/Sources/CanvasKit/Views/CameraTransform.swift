#if canImport(UIKit)
import SwiftUI

/// Places world-space content on screen: `screen = offset + world × zoom`.
/// Only this view reads the live camera, so the content's body is not
/// re-evaluated on every pan or pinch frame.
struct CameraTransform<Content: View>: View {
    let camera: CanvasCamera
    @ContentBuilder let content: Content

    var body: some View {
        content
            .scaleEffect(camera.zoom, anchor: .topLeading)
            .offset(x: camera.offset.x, y: camera.offset.y)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
#endif
