import Foundation

/// A frozen feedback package: one message, grouped by snapshot.
public struct FeedbackPackage: Hashable, Sendable {
    public struct Group: Hashable, Sendable {
        public var snapshot: Snapshot
        public var screenTitle: String
        public var laneTitle: String
        public var items: [BatchItem]
        /// File name of the annotated composite attachment.
        public var compositeFileName: String
        /// Highest iteration of the snapshot's proposal on the canvas (nil for Now).
        public var latestIteration: Int?
        /// Proposal ids that already exist on the snapshot's screen.
        public var existingProposalIds: [String]
        public var isProposal: Bool { snapshot.role == .proposal }
    }

    public var batchId: String
    public var canvasTitle: String
    public var thread: ThreadBinding
    public var groups: [Group]
    public var isRepeat: Bool
    public var createdAt: Date
    public var directive: AgentDirective

    public var items: [BatchItem] { groups.flatMap(\.items) }
    public var manifestFileName: String { "drawspeak-feedback-\(batchId).json" }
    /// The exact marker written into the first line of the message, used to
    /// reconcile Delivery Unknown: `[drawspeak-batch:<batchId>]`.
    public var marker: String { Self.marker(batchId: batchId) }

    public static func marker(batchId: String) -> String { "[drawspeak-batch:\(batchId)]" }
}
