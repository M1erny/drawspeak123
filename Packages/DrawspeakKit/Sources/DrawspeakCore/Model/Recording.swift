import Foundation

public struct Recording: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var duration: TimeInterval
    /// Saved audio; `nil` until capture produced bytes.
    public var audio: BlobRef?
    public var state: RecordingState
    public var transcript: Transcript?

    public init(id: UUID = UUID(), startedAt: Date, duration: TimeInterval = 0, audio: BlobRef? = nil, state: RecordingState, transcript: Transcript? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
        self.audio = audio
        self.state = state
        self.transcript = transcript
    }
}
