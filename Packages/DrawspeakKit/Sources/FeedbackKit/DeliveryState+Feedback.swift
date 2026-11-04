import DrawspeakCore
import Foundation

extension DeliveryState {
    var feedbackLabel: String {
        switch self {
        case .readyToSend: String(localized: "Ready to Send", bundle: .module)
        case .uploading(let done, let total): String(localized: "Uploading \(done) of \(total)", bundle: .module)
        case .sending: String(localized: "Sending…", bundle: .module)
        case .sent: String(localized: "Sent", bundle: .module)
        case .deliveryUnknown: String(localized: "Not Confirmed", bundle: .module)
        case .failed: String(localized: "Failed", bundle: .module)
        }
    }
}
