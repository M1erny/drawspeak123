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
    }

    public var batchId: String
    public var canvasTitle: String
    public var thread: ThreadBinding
    public var groups: [Group]
    public var isRepeat: Bool
    public var createdAt: Date

    public var items: [BatchItem] { groups.flatMap(\.items) }
    public var manifestFileName: String { "drawspeak-feedback-\(batchId).json" }
    /// The marker written into the message, used to reconcile Delivery Unknown.
    public var marker: String { "drawspeak-batch:\(batchId)" }
}
