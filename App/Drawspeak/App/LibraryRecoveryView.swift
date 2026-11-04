import DrawspeakCore
import SwiftUI

/// Shown when the saved library exists but cannot be read. Nothing is overwritten.
struct LibraryRecoveryView: View {
    let error: String
    let fileURL: URL?
    let model: AppModel
    @State private var confirmsFresh = false

    var body: some View {
        ContentUnavailableView {
            Label("Your reviews could not be opened", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Drawspeak has not changed the saved file. \(error)")
        } actions: {
            Button("Try Again") { Task { await model.retryOpening() } }
                .buttonStyle(.borderedProminent)
            if fileURL != nil {
                Button("Start with an Empty Library…") { confirmsFresh = true }
            }
        }
        .confirmationDialog("Start with an empty library?", isPresented: $confirmsFresh, titleVisibility: .visible) {
            Button("Start Empty Library", role: .destructive) { Task { await model.startFresh() } }
        } message: {
            Text("The unreadable file is kept next to the new library so it can be recovered later.")
        }
    }
}
