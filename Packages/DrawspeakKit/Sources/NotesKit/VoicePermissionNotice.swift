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
        VStack(alignment: .leading, spacing: 12) {
            Label(issue == .permissionDenied ? "Microphone Access Is Off" : "Microphone Unavailable", systemImage: "mic.slash")
                .font(.headline)
            Text(issue == .permissionDenied
                 ? "Microphone access is off. You can type your comment, or allow access in Settings."
                 : "The microphone is unavailable. You can type your comment, or try recording again later.")
            ViewThatFits(in: .horizontal) {
                HStack { VoiceNoticeActions(issue: issue, onOpenSettings: onOpenSettings, onDismiss: onDismiss) }
                VStack(alignment: .leading) { VoiceNoticeActions(issue: issue, onOpenSettings: onOpenSettings, onDismiss: onDismiss) }
            }
        }
        .padding().background(Theme.surface, in: .rect(cornerRadius: Theme.cardCornerRadius))
        .foregroundStyle(Theme.ink)
    }


}

#Preview { VoicePermissionNotice(onOpenSettings: {}, onDismiss: {}) }
