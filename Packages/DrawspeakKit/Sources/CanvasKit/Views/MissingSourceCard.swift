#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Shown instead of a snapshot whose image or HTML bytes are gone.
struct MissingSourceCard: View {
    let snapshot: Snapshot

    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "File Missing", bundle: .module), systemImage: "exclamationmark.triangle")
        } description: {
            Text("Import \(expectedFileName) again.", bundle: .module, comment: "Filename to import again.")
        }
        .foregroundStyle(Theme.secondaryInk)
    }

    private var expectedFileName: String {
        if case .manualImport(let fileName) = snapshot.origin { return fileName }
        return snapshot.title
    }
}
#endif
