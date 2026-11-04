import SwiftUI
import T3Kit

/// Pairing form in its own sheet: Close leading, Connect trailing (from T3PairingView).
struct T3PairingSheet: View {
    let connection: T3Connection
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            T3PairingView(connection: connection, onPaired: onClose)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close, action: onClose)
                    }
                }
        }
        .presentationSizing(.form)
    }
}
