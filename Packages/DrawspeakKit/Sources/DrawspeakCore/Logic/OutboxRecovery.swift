import Foundation

public enum OutboxRecovery {
    /// After a restart nothing is sent automatically. Uploads that never reached the
    /// message step become Ready to Send; a started message becomes Delivery Unknown.
    public static func recover(_ entry: OutboxEntry) -> OutboxEntry {
        var entry = entry
        switch entry.state {
        case .uploading:
            entry.state = .readyToSend
        case .sending:
            entry.state = .deliveryUnknown
        default:
            break
        }
        return entry
    }
}
