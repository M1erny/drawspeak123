import Foundation

/// A text WebSocket. Injected so the realtime transcriber is testable without a network.
nonisolated public protocol RealtimeTransport: Sendable {
    func send(_ text: String) async throws
    /// The next text frame; nil for a frame that is not text. Throws once the socket closed.
    func receive() async throws -> String?
    func close()
}

/// `URLSessionWebSocketTask` transport. Connecting starts at creation; sends wait for the handshake.
nonisolated struct URLSessionRealtimeTransport: RealtimeTransport {
    private static let session = URLSession(configuration: .ephemeral)
    private let task: URLSessionWebSocketTask

    init(request: URLRequest, session: URLSession = Self.session) {
        task = session.webSocketTask(with: request)
        task.resume()
    }

    func send(_ text: String) async throws {
        try await task.send(.string(text))
    }

    func receive() async throws -> String? {
        switch try await task.receive() {
        case .string(let text): text
        case .data(let data): String(data: data, encoding: .utf8)
        @unknown default: nil
        }
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
    }
}
