import Foundation

public enum OutboxRecovery {
    /// After a restart nothing is sent automatically.
    ///
    /// `ThreadService.send` uploads and then submits the message in one call, so
    /// once an entry was durably checkpointed as Uploading or Sending the message
    /// request may have started: it becomes Delivery Unknown and must be reconciled.
    /// Only Ready to Send and Failed prove that no message request started.
    public static func recover(_ entry: OutboxEntry) -> OutboxEntry {
        var entry = entry
        switch entry.state {
        case .uploading, .sending:
            entry.state = .deliveryUnknown
            if let last = entry.attempts.indices.last, entry.attempts[last].endedAt == nil {
                entry.attempts[last].outcome = "interrupted"
            }
        case .readyToSend, .sent, .deliveryUnknown, .failed:
            break
        }
        return entry
    }
}
