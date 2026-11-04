#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Shown instead of a snapshot whose image or HTML bytes are gone.
struct MissingSourceCard: View {
    let snapshot: Snapshot

    var body: some View {
        ContentUnavailableView {
            Label("Source file is missing", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Expected \(snapshot.kind == .html ? "HTML" : "image") file: \(expectedFileName). Comments stay with this version. Import the original file again to review it.")
        }
        .foregroundStyle(Theme.secondaryInk)
    }

    private var expectedFileName: String {
        if case .manualImport(let fileName) = snapshot.origin { return fileName }
        return snapshot.title
    }
}
#endif
