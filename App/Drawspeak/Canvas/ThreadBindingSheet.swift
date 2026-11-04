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
                    T3ThreadPickerView(service: service, selected: workspace.currentCanvas?.thread) { binding in
                        guard let canvasId = workspace.currentCanvasId else { return }
                        if workspace.bindThread(binding, to: canvasId) {
                            dismiss()
                            onBound()
                        } else {
                            rejected = true
                        }
                    }
                } else {
                    T3PairingView(connection: connection)
                }
            }
            .navigationTitle(connection.threadService == nil ? "Connect to T3 Code" : "Choose Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("This canvas already sent feedback to another thread", isPresented: $rejected) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A canvas belongs to one thread. Create a new canvas for the other thread.")
            }
        }
    }
}
