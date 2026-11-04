#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Canvas chrome metrics shared across the module, independent of world geometry.
enum CanvasMetrics {
    static let spacing = 4.0
    static let inset = 6.0
    static let detailSpacing = 2.0
    static let chipInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    static let statusInsets = EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
    static let separator = Color.primary.opacity(0.2)
}
#endif
