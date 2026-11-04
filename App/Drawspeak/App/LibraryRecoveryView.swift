import DrawspeakCore
import SwiftUI

/// Shown when the saved library exists but cannot be read. Nothing is overwritten.
struct LibraryRecoveryView: View {
    let error: String
    let fileURL: URL?
    let model: AppModel
    @State private var confirmsStartOver = false

    var body: some View {
        ContentUnavailableView {
            Label("Can't Open Library", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("\(error) The file is unchanged.", comment: "Placeholder is the reason the library could not be read.")
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
            if fileURL != nil {
                Button("Start Over…", action: requestStartOver)
                    .confirmationDialog("Start Over?", isPresented: $confirmsStartOver, titleVisibility: .visible) {
                        Button("Start Over", role: .destructive, action: startOver)
                    } message: {
                        Text("The unreadable file is kept.")
                    }
            }
        }
    }

    private func retry() {
        Task { await model.retryOpening() }
    }

    private func requestStartOver() {
        confirmsStartOver = true
    }

    private func startOver() {
        Task { await model.startFresh() }
    }
}
