import DrawspeakCore
import SwiftUI
import T3Kit

/// Pairs with T3 Code if needed, then binds the current canvas to one thread.
struct ThreadBindingSheet: View {
    let workspace: Workspace
    let connection: T3Connection
    var onBound: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var rejected = false

    var body: some View {
        NavigationStack {
            Group {
                if let service = connection.threadService {
                    T3ThreadPickerView(service: service, selected: workspace.currentCanvas?.thread, onPick: bind)
                } else {
                    T3PairingView(connection: connection)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: dismiss.callAsFunction)
                }
            }
            .alert("Thread Can't Change", isPresented: $rejected) {
            } message: {
                Text("Create a new canvas for another thread.")
            }
        }
        .presentationSizing(.form)
    }

    private func bind(_ binding: ThreadBinding) {
        guard let canvasId = workspace.currentCanvasId else { return }
        if workspace.bindThread(binding, to: canvasId) {
            onBound()
            dismiss()
        } else {
            rejected = true
        }
    }
}
