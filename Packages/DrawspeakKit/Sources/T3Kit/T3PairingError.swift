import Foundation

nonisolated public enum T3PairingError: Error, Sendable, LocalizedError {
    case invalidHost, unreachable, codeRejected, expired, serverError(Int), invalidResponse
    case approvalRejected(String)
    public var message: String {
        switch self {
        case .invalidHost: "Enter an HTTPS host, or HTTP on localhost."
        case .unreachable: "Cannot reach T3 Code. Check the host and your Tailscale connection."
        case .codeRejected: "The pairing code was rejected. It may be expired, already used, or unable to grant this access level."
        case .expired: "The authorization code expired. Create a new pairing code."
        case .serverError(let status): "T3 Code returned an error (HTTP \(status))."
        case .approvalRejected(let reason): reason
        case .invalidResponse: "T3 Code returned an invalid response."
        }
    }
    public var errorDescription: String? { message }
}
