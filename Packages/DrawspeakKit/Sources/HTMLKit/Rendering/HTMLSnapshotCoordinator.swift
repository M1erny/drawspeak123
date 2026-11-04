#if canImport(UIKit)
import DrawspeakCore
import Foundation

/// Keeps the web view session of one `HTMLSnapshotView` across SwiftUI updates.
public final class HTMLSnapshotCoordinator {
    let session: HTMLWebViewSession

    init(viewport: Viewport) {
        session = HTMLWebViewSession(viewport: viewport)
    }
}
#endif
