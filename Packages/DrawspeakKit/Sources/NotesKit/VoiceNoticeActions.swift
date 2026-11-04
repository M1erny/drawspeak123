import SwiftUI
import DrawspeakCore

struct VoiceNoticeActions: View {
    let issue: Workspace.VoiceIssue
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        if issue == .permissionDenied {
            Button("Open Settings", systemImage: "gear", action: onOpenSettings)
                .frame(minHeight: Theme.minTarget)
        }
        Button("Type Instead", systemImage: "keyboard", action: onDismiss)
            .frame(minHeight: Theme.minTarget)
    }
}

#Preview { VoiceNoticeActions(issue: .permissionDenied, onOpenSettings: {}, onDismiss: {}) }
