import SwiftUI
import DrawspeakCore

/// Where a send stands, as the result view shows it.
enum FeedbackResultPhase: Equatable {
    case working, sent, unknown, failed, ready

    /// Failed, not confirmed and not found states offer a way forward.
    var offersAction: Bool { self == .unknown || self == .failed || self == .ready }

    var symbol: String {
        switch self {
        case .working: "paperplane"
        case .sent: "checkmark.circle.fill"
        case .unknown: "questionmark.circle"
        case .failed: "exclamationmark.triangle.fill"
        case .ready: "paperplane.circle"
        }
    }

    var tint: Color {
        switch self {
        case .working, .ready: Theme.action
        case .sent: .green
        case .unknown, .failed: .orange
        }
    }

    var title: String {
        switch self {
        case .working: String(localized: "Sending…", bundle: .module)
        case .sent: String(localized: "Feedback Sent", bundle: .module)
        case .unknown: String(localized: "Delivery Not Confirmed", bundle: .module)
        case .failed: String(localized: "Not All Feedback Was Sent", bundle: .module)
        case .ready: String(localized: "Ready to Send", bundle: .module)
        }
    }
}
