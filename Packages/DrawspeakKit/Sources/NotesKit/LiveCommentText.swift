import SwiftUI

struct LiveCommentText: View {
    let text: String
    let partial: String
    private var committed: String {
        guard !partial.isEmpty, text.hasSuffix(partial) else { return text }
        return String(text.dropLast(partial.count))
    }
    var body: some View {
        Text("\(Text(verbatim: committed))\(Text(verbatim: partial).foregroundStyle(.secondary))", bundle: .module)
            .textSelection(.enabled)
            .accessibilityLabel(Text("Live Transcript: \(text)", bundle: .module))
    }
}
