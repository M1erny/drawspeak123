import Foundation

public enum DeliveryState: Codable, Hashable, Sendable {
    /// Frozen and waiting for an explicit Send (offline or after restart).
    case readyToSend
    case uploading(done: Int, total: Int)
    /// The message request started; the outcome is not known yet.
    case sending
    /// The server acknowledged the message.
    case sent
    /// The request may have reached the server. Reconcile before any retry.
    case deliveryUnknown
    /// Failed before the message request started; nothing was delivered.
    case failed(reason: String)

    public var isActive: Bool {
        switch self {
        case .uploading, .sending: true
        default: false
        }
    }
}
