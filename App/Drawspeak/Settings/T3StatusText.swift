import SwiftUI
import T3Kit

/// The T3 connection state as a short value.
struct T3StatusText: View {
    let state: T3ConnectionState

    var body: some View {
        switch state {
        case .notPaired: Text("Not Connected")
        case .connecting: Text("Connecting…")
        case .connected: Text("Connected")
        case .expired: Text("Expired")
        case .failed(let message): Text(message)
        }
    }
}
