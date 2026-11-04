import Foundation
import Synchronization

/// Serves canned replies per host so parallel tests never share state. No real network is used.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    enum Reply {
        case response(status: Int, body: Data)
        case redirect(to: URL)
        case failure(URLError.Code)
    }

    struct Captured {
        var request: URLRequest
        var body: Data
    }

    final class Stub: Sendable {
        let endpoint: URL
        let reply: Reply
        private let captured = Mutex<[Captured]>([])

        init(host: String, reply: Reply) {
            endpoint = URL(string: "https://\(host)/v1/speech-to-text")!
            self.reply = reply
        }

        var requests: [Captured] { captured.withLock { $0 } }

        func record(_ item: Captured) { captured.withLock { $0.append(item) } }

        var session: URLSession {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StubURLProtocol.self]
            return URLSession(configuration: configuration)
        }
    }

    private static let stubs = Mutex<[String: Stub]>([:])

    /// A stub on a unique host. `redirectTarget` receives its own recorder on a second host.
    static func make(_ reply: Reply) -> Stub {
        let stub = Stub(host: "stub-\(UUID().uuidString.lowercased()).test", reply: reply)
        stubs.withLock { $0[stub.endpoint.host() ?? ""] = stub }
        return stub
    }

    static func makeTarget() -> Stub {
        make(.response(status: 200, body: Data("{}".utf8)))
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let stub = Self.stubs.withLock({ $0[url.host() ?? ""] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        stub.record(Captured(request: request, body: Self.readBody(of: request)))
        switch stub.reply {
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .redirect(let target):
            let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: ["Location": target.absoluteString])!
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
            // A refused redirect makes the 3xx response the final result, as with a real connection.
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        case .response(let status, let body):
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
