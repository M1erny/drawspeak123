import Foundation
import DrawspeakCore
import Testing
@testable import RefineKit

private nonisolated final class StubState: @unchecked Sendable {
    private let lock = NSLock()
    private var status = 200
    private var body = Data()
    private var failure: URLError?
    private var requests: [URLRequest] = []

    func configure(status: Int = 200, body: String = "", failure: URLError? = nil) {
        lock.lock()
        defer { lock.unlock() }
        self.status = status
        self.body = Data(body.utf8)
        self.failure = failure
        requests = []
    }

    func record(_ request: URLRequest) -> (Int, Data, URLError?) {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
        return (status, body, failure)
    }

    var recorded: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }
}

private nonisolated final class StubProtocol: URLProtocol, @unchecked Sendable {
    static let state = StubState()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data, failure) = Self.state.record(request)
        if let failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized)
struct ClaudeRefinerTests {
    private var context: RefineContext {
        .init(screenTitle: "Checkout", versionLabel: "v4", markKind: "circle", componentLabel: "Pay", language: "pol")
    }

    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: configuration)
    }

    @Test func requestContract() throws {
        let refiner = ClaudeRefiner(keyStore: .init(fixedKey: "synthetic-key"))
        let png = Data([0, 1, 2, 3])
        let request = try refiner.buildRequest(transcript: "Zwiększ przycisk.", regionPNG: png, context: context)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.timeoutInterval == 30)
        #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "synthetic-key")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2026-10-21")
        #expect(request.value(forHTTPHeaderField: "anthropic-beta") == "server-side-fallback-2026-07-01")
        let bodyData = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(body["model"] as? String == "claude-sonnet-5-5")
        #expect(body["max_tokens"] as? Int == 1024)
        #expect((body["output_config"] as? [String: String])?["effort"] == "low")
        #expect(body["fallbacks"] as? String == "default")
        #expect(body["system"] as? String == ClaudeRefiner.systemPrompt)
        for key in ["temperature", "top_p", "top_k", "thinking"] { #expect(body[key] == nil) }
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        #expect(messages[0]["role"] as? String == "user")
        let blocks = try #require(messages[0]["content"] as? [[String: Any]])
        #expect(blocks.count == 2)
        #expect(blocks[0]["type"] as? String == "image")
        let source = try #require(blocks[0]["source"] as? [String: String])
        #expect(source == ["type": "base64", "media_type": "image/png", "data": png.base64EncodedString()])
        #expect(blocks[1]["type"] as? String == "text")
        #expect(blocks[1]["text"] as? String == "Screen: Checkout\nVersion: v4\nMark: circle\nComponent: Pay\nTranscript: Zwiększ przycisk.")
    }

    @Test func optionalImageAndComponentAndOverrides() throws {
        let refiner = ClaudeRefiner(keyStore: .init(fixedKey: "test"), endpoint: URL(string: "https://example.invalid/messages")!, model: "test-model")
        let context = RefineContext(screenTitle: "A", versionLabel: "B", markKind: "C", componentLabel: nil, language: nil)
        let request = try refiner.buildRequest(transcript: "", regionPNG: nil, context: context)
        #expect(request.url?.host == "example.invalid")
        let bodyData = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(body["model"] as? String == "test-model")
        let messages = try #require(body["messages"] as? [[String: Any]])
        let blocks = try #require(messages[0]["content"] as? [[String: Any]])
        #expect(blocks.count == 1)
        #expect(blocks[0]["text"] as? String == "Screen: A\nVersion: B\nMark: C\nTranscript: ")
    }

    @Test func joinsTextAndIgnoresThinking() async throws {
        StubProtocol.state.configure(body: #"{"stop_reason":"end_turn","content":[{"type":"thinking","thinking":"private"},{"type":"text","text":"Pierwsze."},{"type":"text","text":"Drugie."}]}"#)
        let session = session()
        defer { session.invalidateAndCancel() }
        let result = try await ClaudeRefiner(keyStore: .init(fixedKey: "test"), session: session).refine(transcript: "raw", regionPNG: nil, context: context)
        #expect(result == "Pierwsze.\nDrugie.")
        #expect(StubProtocol.state.recorded.count == 1)
    }

    @Test(arguments: [401, 403, 429, 529, 500, 503, 400])
    func mapsHTTPFailures(status: Int) async {
        StubProtocol.state.configure(status: status, body: "not JSON")
        let session = session()
        defer { session.invalidateAndCancel() }
        let code: RefineFailure.Code = switch status {
        case 401, 403: .auth
        case 429, 529: .rateLimited
        case 500...599: .upstream
        default: .invalidResponse
        }
        await #expect(throws: RefineFailure(code: code)) {
            try await ClaudeRefiner(keyStore: .init(fixedKey: "test"), session: session).refine(transcript: "raw", regionPNG: nil, context: context)
        }
        #expect(StubProtocol.state.recorded.count == 1)
    }

    @Test func refusalTakesPriority() throws {
        let data = Data(#"{"stop_reason":"refusal","content":[{"type":"text","text":"do not return"}]}"#.utf8)
        #expect(throws: RefineFailure(code: .refused)) { try ClaudeRefiner.parseResponse(data, statusCode: 200) }
        #expect(throws: RefineFailure(code: .refused)) {
            try ClaudeRefiner.parseResponse(Data(#"{"stop_reason":"refusal"}"#.utf8), statusCode: 200)
        }
    }

    @Test func acceptsTruncatedText() throws {
        #expect(try ClaudeRefiner.parseResponse(Data(#"{"stop_reason":"max_tokens","content":[{"type":"text","text":"Zwiększ przycisk."}]}"#.utf8), statusCode: 200) == "Zwiększ przycisk.")
    }

    @Test(arguments: ["{}", "invalid", #"{"content":[]}"#, #"{"stop_reason":"max_tokens","content":[{"type":"text","text":"  "}]}"#, #"{"content":[{"type":"thinking","thinking":"hidden"}]}"#])
    func invalidResponses(body: String) {
        #expect(throws: RefineFailure(code: .invalidResponse)) { try ClaudeRefiner.parseResponse(Data(body.utf8), statusCode: 200) }
    }

    @Test(arguments: ["", "  \n", "$(DSAnthropicAPIKey)"])
    func missingKeyNeverRequests(key: String) async {
        StubProtocol.state.configure()
        let session = session()
        defer { session.invalidateAndCancel() }
        let refiner = ClaudeRefiner(keyStore: .init(fixedKey: key), session: session)
        #expect(!refiner.isConfigured)
        await #expect(throws: RefineFailure(code: .notConfigured)) { try await refiner.refine(transcript: "raw", regionPNG: nil, context: context) }
        #expect(StubProtocol.state.recorded.isEmpty)
    }

    @Test func transportFailureDoesNotRetry() async {
        StubProtocol.state.configure(failure: URLError(.timedOut))
        let session = session()
        defer { session.invalidateAndCancel() }
        await #expect(throws: RefineFailure(code: .network)) {
            try await ClaudeRefiner(keyStore: .init(fixedKey: "test"), session: session).refine(transcript: "raw", regionPNG: nil, context: context)
        }
        #expect(StubProtocol.state.recorded.count == 1)
    }
}
