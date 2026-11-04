import DrawspeakCore

extension DeliveryState {
    var feedbackLabel: String {
        switch self {
        case .readyToSend: "Ready to Send"
        case .uploading(let done, let total): "Uploading \(done) of \(total)"
        case .sending: "Sending…"
        case .sent: "Sent"
        case .deliveryUnknown: "Delivery Unknown"
        case .failed: "Failed"
        }
    }
}
