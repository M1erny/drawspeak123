import SwiftUI
import DrawspeakCore

public struct VoicePermissionNotice: View {
    private let issue: Workspace.VoiceIssue
    private let onOpenSettings: () -> Void
    private let onDismiss: () -> Void

    public init(issue: Workspace.VoiceIssue = .permissionDenied, onOpenSettings: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.issue = issue
        self.onOpenSettings = onOpenSettings
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Label {
                if issue == .permissionDenied { Text("Microphone Off", bundle: .module) }
                else { Text("Microphone Unavailable", bundle: .module) }
            } icon: { Image(systemName: "mic.slash") }
            ViewThatFits(in: .horizontal) {
                HStack { VoiceNoticeActions(issue: issue, onOpenSettings: onOpenSettings, onDismiss: onDismiss) }
                VStack(alignment: .leading) { VoiceNoticeActions(issue: issue, onOpenSettings: onOpenSettings, onDismiss: onDismiss) }
            }
        }
        .padding().background(Theme.surface, in: .rect(cornerRadius: Theme.cardCornerRadius))
    }
}
