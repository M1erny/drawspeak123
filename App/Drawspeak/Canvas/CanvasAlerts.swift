import SwiftUI

/// Errors that need reading, and the microphone notice with its Settings link.
struct CanvasAlerts: ViewModifier {
    @Bindable var controller: CanvasController
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .alert(controller.alert?.title ?? "", item: $controller.alert) { _ in
            } message: { alert in
                Text(alert.message)
            }
            .alert(voiceIssueTitle, isPresented: $controller.showsVoiceIssue) {
                Button("Open Settings", action: openSettings)
                Button("Cancel", role: .cancel) {}
            }
    }

    private var voiceIssueTitle: LocalizedStringResource {
        controller.workspace.voiceIssue == .microphoneUnavailable ? "Microphone Unavailable" : "Microphone Off"
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}
