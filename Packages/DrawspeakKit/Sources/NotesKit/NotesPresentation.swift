import Foundation
import DrawspeakCore

/// Shared labels always describe the immutable source, not the lane's current selection.
enum NotesPresentation {
    static func sourceLabel(_ snapshot: Snapshot, in canvas: ReviewCanvas) -> String {
        let screen = canvas.screens.first { $0.id == snapshot.screenId }?.title ?? "Screen"
        let version = snapshot.proposalId.map { CanvasLayout.proposalTitle($0) + " · " + snapshot.versionLabel } ?? snapshot.versionLabel
        return screen + " · " + version
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let value = seconds.isFinite ? Int(max(0, seconds).rounded(.down)) : 0
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    static func failure(_ code: String) -> String {
        switch code {
        case "not_configured": "Add an ElevenLabs key in Settings"
        case "network": "Offline. Audio is saved."
        case "auth": "ElevenLabs rejected the key"
        case "rate_limited": "Too many requests. Try later."
        case "audio_missing": "The saved audio could not be found."
        case "interrupted", "aborted": "Transcription was interrupted. Audio is saved."
        default: "Transcription failed. Audio is saved."
        }
    }
}
