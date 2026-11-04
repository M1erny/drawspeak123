import Foundation

public enum RecordingState: Codable, Hashable, Sendable {
    /// Capturing; live transcript segments may already be on the note.
    case recording
    /// Audio is saved locally; transcription not started.
    case saved
    /// Audio is saved; waiting for the live session to finish or for the batch fallback.
    case transcribing
    case transcribed
    /// The transcription failed; audio stays for a deliberate retry.
    case failed(code: String, mayHaveBeenProcessed: Bool)
    /// Capture ended without Stop (app moved away, canvas changed, interruption).
    case interrupted
    /// The captured file could not be moved into the blob store. The temporary
    /// file at `tempPath` is kept so `Workspace.retrySavingAudio` can store it.
    case saveFailed(tempPath: String)

    public var isInFlight: Bool {
        switch self {
        case .recording, .transcribing: true
        case .saved, .transcribed, .failed, .interrupted, .saveFailed: false
        }
    }
}
