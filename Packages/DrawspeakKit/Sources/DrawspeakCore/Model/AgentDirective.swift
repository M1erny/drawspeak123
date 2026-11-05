import Foundation

/// What the reviewer wants the agent to do with a batch of comments. Written into the
/// message text, so the agent no longer guesses between "two new variants" and
/// "continue what is on the canvas".
public struct AgentDirective: Codable, Hashable, Sendable {
    public enum Mode: String, Codable, CaseIterable, Sendable {
        /// Add the next iteration to the proposals the comments are on.
        case continueProposals
        /// Create new alternative proposals.
        case newVariants
        /// Answer in text only; build nothing.
        case replyOnly
    }

    public static let variantRange = 1...3

    public var mode: Mode
    /// Number of new proposals for `newVariants`.
    public var variantCount: Int
    /// Free text from the reviewer, passed on verbatim.
    public var note: String

    public init(mode: Mode = .newVariants, variantCount: Int = 2, note: String = "") {
        self.mode = mode
        self.variantCount = min(max(variantCount, Self.variantRange.lowerBound), Self.variantRange.upperBound)
        self.note = note
    }

    /// The mode to start from: continue when every comment is on a proposal,
    /// otherwise new variants (a comment on Now has no proposal to continue).
    public static func suggested(forProposalFlags flags: [Bool]) -> AgentDirective {
        AgentDirective(mode: !flags.isEmpty && flags.allSatisfy { $0 } ? .continueProposals : .newVariants)
    }
}
