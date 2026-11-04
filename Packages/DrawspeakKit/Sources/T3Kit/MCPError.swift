import Foundation

nonisolated public enum MCPError: Error, Sendable, LocalizedError {
    case unauthorized, http(Int), transport, invalidResponse, rpc(code: Int, message: String), tool(code: String, message: String), unsupported
    public var errorDescription: String? {
        switch self {
        case .unauthorized: "Pair with T3 Code again."
        case .http(let status): "T3 Code returned HTTP \(status)."
        case .transport: "The connection to T3 Code was interrupted."
        case .invalidResponse: "T3 Code returned an invalid response."
        case .rpc(_, let message), .tool(_, let message): message
        case .unsupported: "Attachment downloads are not supported over MCP."
        }
    }
}
