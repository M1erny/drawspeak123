import Foundation

public struct DeliveryReceipt: Codable, Hashable, Sendable {
    public var threadId: String
    public var messageId: String?
    public var acknowledgedAt: Date
    public var attachmentCount: Int
    /// How the server confirmed the message.
    public var confirmation: Confirmation

    public enum Confirmation: String, Codable, Hashable, Sendable {
        case response
        case reconciledFromThread
    }

    public init(threadId: String, messageId: String?, acknowledgedAt: Date, attachmentCount: Int, confirmation: Confirmation) {
        self.threadId = threadId
        self.messageId = messageId
        self.acknowledgedAt = acknowledgedAt
        self.attachmentCount = attachmentCount
        self.confirmation = confirmation
    }
}
