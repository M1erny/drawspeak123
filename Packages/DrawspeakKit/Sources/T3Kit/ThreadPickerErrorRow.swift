import SwiftUI
import DrawspeakCore

struct ThreadPickerErrorRow: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        Section {
            Text(verbatim: message)
                .foregroundStyle(.secondary)
            Button(action: onRetry) {
                Label {
                    Text("Try Again", bundle: .module)
                } icon: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .frame(minHeight: Theme.minTarget)
        }
    }
}
