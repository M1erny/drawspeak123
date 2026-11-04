import Foundation

public struct Recording: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var duration: TimeInterval
    /// Saved audio; `nil` until capture produced bytes.
    public var audio: BlobRef?
    public var state: RecordingState
    public var transcript: Transcript?
    /// The note's text revision when this recording started. A transcript fills
    /// the text only when no edit happened since (including clearing the text).
    /// `nil` for recordings stored before this was tracked.
    public var textRevisionAtStart: Int?
    /// The note's text revision right after the last live segment was added to it.
    /// Live segments keep filling the text only while the revision still matches.
    public var liveTextRevision: Int?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        duration: TimeInterval = 0,
        audio: BlobRef? = nil,
        state: RecordingState,
        transcript: Transcript? = nil,
        textRevisionAtStart: Int? = nil,
        liveTextRevision: Int? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
        self.audio = audio
        self.state = state
        self.transcript = transcript
        self.textRevisionAtStart = textRevisionAtStart
        self.liveTextRevision = liveTextRevision
    }
}
