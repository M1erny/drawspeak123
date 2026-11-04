import Foundation

/// Whether a note can go into the default feedback package.
public enum NoteReadiness: Hashable, Sendable {
    /// Saved non-empty text, valid anchor, available source, not yet sent at this revision.
    case ready
    /// Ready text but the snapshot image/HTML is missing or does not match.
    case sourceUnavailable(String)
    /// A mark without text.
    case markOnly
    case recording
    case transcribing
    /// This revision was already acknowledged by the server.
    case sent

    public var isPending: Bool {
        switch self {
        case .markOnly, .recording, .transcribing: true
        default: false
        }
    }

    public var label: String {
        switch self {
        case .ready: "Ready"
        case .sourceUnavailable(let reason): reason
        case .markOnly: "No comment yet"
        case .recording: "Recording"
        case .transcribing: "Transcribing"
        case .sent: "Sent"
        }
    }
}
