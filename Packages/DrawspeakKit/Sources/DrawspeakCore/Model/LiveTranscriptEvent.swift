import Foundation

/// One event from live (streaming) transcription of the active recording.
///
/// A capture delivers any number of `partial` and `committed` events and at most
/// one terminal event: `finished` after Stop, or `failed` at any time. Nothing is
/// delivered after a discard.
public enum LiveTranscriptEvent: Hashable, Sendable {
    /// The in-progress text of the segment not yet committed; replaces the previous partial.
    case partial(String)
    /// A final segment; it never changes again.
    case committed(String)
    /// The session closed cleanly after Stop. Carries every committed segment, joined.
    case finished(String)
    /// The live session ended without a usable result (for example `auth_error` or `network`).
    case failed(code: String)
}

public extension Transcript {
    /// Provider and model recorded for live transcripts.
    static let liveProvider = "elevenlabs"
    static let liveModelId = "scribe_v2_realtime"
}
