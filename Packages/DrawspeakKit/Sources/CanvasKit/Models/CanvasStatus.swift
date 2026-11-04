import Foundation
import Observation
import SwiftUI

/// A short transient hint over the canvas, also announced to VoiceOver.
@Observable
final class CanvasStatus {
    private(set) var message: String?
    @ObservationIgnored private var clearTask: Task<Void, Never>?

    func show(_ text: String) {
        message = text
        AccessibilityNotification.Announcement(text).post()
        clearTask?.cancel()
        clearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}
