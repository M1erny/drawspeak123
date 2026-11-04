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
    /// Set when a review is split into several messages; nil for a single message.
    public var part: Part? = nil

    /// One message of a review that is sent as several messages, because one T3 message
    /// carries at most `FeedbackPackageSplitter.maxAttachmentsPerMessage` attachments.
    public struct Part: Codable, Hashable, Sendable {
        /// 1-based position in the series.
        public var index: Int
        public var count: Int
        /// The batch id shared by every part; each part's own batch id is `<seriesId>-<index>`.
        public var seriesId: String

        public init(index: Int, count: Int, seriesId: String) {
            self.index = index
            self.count = count
            self.seriesId = seriesId
        }

        public var isLast: Bool { index == count }
    }

    public var items: [BatchItem] { groups.flatMap(\.items) }
    public var manifestFileName: String { "drawspeak-feedback-\(batchId).json" }
    /// The exact marker written into the first line of the message, used to
    /// reconcile Delivery Unknown: `[drawspeak-batch:<batchId>]`.
    public var marker: String { Self.marker(batchId: batchId) }

    public static func marker(batchId: String) -> String { "[drawspeak-batch:\(batchId)]" }
}
