#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

struct VersionMenuEntry: Identifiable {
    let id: String
    let title: String
    let capturedAt: Date
    let summary: String?
}
#endif
