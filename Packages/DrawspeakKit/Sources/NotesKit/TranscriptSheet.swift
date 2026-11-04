import SwiftUI

struct TranscriptSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView { Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }
                .navigationTitle(Text("Transcript", bundle: .module))
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(role: .close, action: close) }
                }
        }
        .presentationSizing(.form)
    }
    private func close() { dismiss() }
}
