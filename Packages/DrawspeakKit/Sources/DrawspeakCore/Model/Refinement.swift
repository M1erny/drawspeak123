import Foundation

/// A Claude rewrite of a note's spoken text. The raw transcript stays on the
/// recording; the note text changes only as described in `Workspace.refine`.
public struct Refinement: Codable, Hashable, Sendable {
    public enum State: Codable, Hashable, Sendable {
        case refining
        case refined
        /// Carries a `RefineFailure.Code` raw value (or "interrupted" after a restart).
        case failed(code: String)
    }

    public var state: State
    /// The note text the request was based on.
    public var rawText: String
    /// The refined text; nil until `state` is `.refined`.
    public var text: String?
    public var modelId: String?
    /// When the request started, or when its result arrived.
    public var at: Date
    /// The recording whose final transcript started the request; nil for a manual run.
    public var recordingId: UUID?

    public init(state: State, rawText: String, text: String? = nil, modelId: String? = nil, at: Date, recordingId: UUID? = nil) {
        self.state = state
        self.rawText = rawText
        self.text = text
        self.modelId = modelId
        self.at = at
        self.recordingId = recordingId
    }
}
