import SwiftUI
import DrawspeakCore

/// Compatibility wrapper for app call sites migrating to SendFeedbackButton.
public struct FeedbackButton: View {
    public let workspace: Workspace
    public let action: () -> Void
    public init(workspace: Workspace, action: @escaping () -> Void) {
        self.workspace = workspace
        self.action = action
    }
    public var body: some View { SendFeedbackButton(workspace: workspace, action: action) }
}
