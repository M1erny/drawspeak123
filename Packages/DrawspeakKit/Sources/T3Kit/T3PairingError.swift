import Foundation

nonisolated public enum T3PairingError: Error, Sendable, LocalizedError {
    case invalidHost, unreachable, codeRejected, expired, serverError(Int), invalidResponse
    case approvalRejected(String)
    public var message: String {
        switch self {
        case .invalidHost: String(localized: "Enter an HTTPS host, or HTTP on localhost.", bundle: .module)
        case .unreachable: String(localized: "Cannot reach T3 Code. Check the host and your Tailscale connection.", bundle: .module)
        case .codeRejected: String(localized: "The pairing code was rejected. It may be expired, already used, or unable to grant this access level.", bundle: .module)
        case .expired: String(localized: "Code expired. Create a new one.", bundle: .module)
        case .serverError(let status): String(localized: "T3 Code returned an error (HTTP \(status)).", bundle: .module)
        case .approvalRejected(let reason): reason
        case .invalidResponse: String(localized: "T3 Code returned an invalid response.", bundle: .module)
        }
    }
    public var errorDescription: String? { message }
}
