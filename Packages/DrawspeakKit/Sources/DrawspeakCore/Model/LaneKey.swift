import Foundation

/// Identifies one lane of a screen: the baseline (Now) or a proposal.
public struct LaneKey: Codable, Hashable, Sendable, CustomStringConvertible {
    public var screenId: String
    /// `nil` is the Now lane.
    public var proposalId: String?

    public init(screenId: String, proposalId: String?) {
        self.screenId = screenId
        self.proposalId = proposalId
    }

    public var description: String { "\(screenId)|\(proposalId ?? "now")" }

    public var isNow: Bool { proposalId == nil }
}
