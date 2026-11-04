import SwiftUI
import T3Kit

/// The pairing form pushed inside the Settings navigation stack. A sheet presented
/// from inside the Settings list was dismissed whenever the list rebuilt
/// (every connection state change), so pairing now uses navigation instead.
struct T3PairingDestination: View {
    let connection: T3Connection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        T3PairingView(connection: connection) { dismiss() }
            .navigationBarTitleDisplayMode(.inline)
    }
}
