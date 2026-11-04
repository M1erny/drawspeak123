import Foundation

public enum RecordingState: Codable, Hashable, Sendable {
    case recording
    /// Audio is saved locally; transcription not started.
    case saved
    case transcribing
    case transcribed
    /// The transcription failed; audio stays for a deliberate retry.
    case failed(code: String, mayHaveBeenProcessed: Bool)
    /// Capture ended without Stop (app moved away, canvas changed, interruption).
    case interrupted

    public var isInFlight: Bool {
        switch self {
        case .recording, .transcribing: true
        default: false
        }
    }
}
