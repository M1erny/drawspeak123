#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Shown instead of a snapshot whose image or HTML bytes are gone.
struct MissingSourceCard: View {
    var body: some View {
        ContentUnavailableView {
            Label("Source file is missing", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Comments stay with this version. Import it again to review it.")
        }
        .foregroundStyle(Theme.secondaryInk)
    }
}
#endif
