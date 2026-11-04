import SwiftUI
import DrawspeakCore

struct VoiceNoticeActions: View {
    let issue: Workspace.VoiceIssue
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void
    var body: some View {
        if issue == .permissionDenied {
            Button(action: onOpenSettings) { Text("Open Settings", bundle: .module) }
                .frame(minHeight: Theme.minTarget)
        }
        Button(action: onDismiss) { Text("Type Instead", bundle: .module) }
            .frame(minHeight: Theme.minTarget)
    }
}
