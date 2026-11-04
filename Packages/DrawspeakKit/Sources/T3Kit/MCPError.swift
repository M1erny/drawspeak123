import Foundation

nonisolated public enum MCPError: Error, Sendable, LocalizedError {
    case unauthorized, http(Int), transport, invalidResponse, rpc(code: Int, message: String), tool(code: String, message: String), unsupported
    public var errorDescription: String? {
        switch self {
        case .unauthorized: String(localized: "Pair with T3 Code again.", bundle: .module)
        case .http(let status): String(localized: "T3 Code returned HTTP \(status).", bundle: .module)
        case .transport: String(localized: "The connection to T3 Code was interrupted.", bundle: .module)
        case .invalidResponse: String(localized: "T3 Code returned an invalid response.", bundle: .module)
        case .rpc(_, let message), .tool(_, let message): message
        case .unsupported: String(localized: "Attachment downloads are not supported over MCP.", bundle: .module)
        }
    }
}
