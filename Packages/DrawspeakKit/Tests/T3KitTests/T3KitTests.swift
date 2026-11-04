import Foundation
import Testing
import CryptoKit
import Synchronization
import DrawspeakCore
@testable import T3Kit

@Suite(.serialized) struct T3KitTests {
    let host = URL(string: "https://fake.test")!
    func credential() -> T3Credentials { T3Credentials(hostURL: host, clientId: "client", accessToken: "fake-token", scope: "orchestration:operate", expiresAt: .distantFuture, accessLevel: "full-access") }
    static func json(_ value: JSONValue, status: Int = 200, headers: [String: String] = [:]) throws -> (Int, [String: String], Data) { (status, headers.merging(["Content-Type": "application/json"]) { old, _ in old }, try JSONEncoder().encode(value)) }
    static func body(_ request: URLRequest) throws -> JSONValue {
        if let data = request.httpBody { return try JSONDecoder().decode(JSONValue.self, from: data) }
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }; var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(contentsOf: buffer.prefix(n)) }
            return try JSONDecoder().decode(JSONValue.self, from: data)
        }
        return .null
    }
    static func rpc(_ body: JSONValue, result: JSONValue) throws -> (Int, [String: String], Data) {
        try json(.object(["jsonrpc": .string("2.0"), "id": body["id"], "result": result]), headers: body["method"].string == "initialize" ? ["Mcp-Session-Id": "session"] : [:])
    }
    static func handshake(_ request: URLRequest, _ body: JSONValue) throws -> (Int, [String: String], Data)? {
        #expect(request.value(forHTTPHeaderField: "Origin") == nil)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json, text/event-stream")
        if body["method"].string == "initialize" {
            #expect(request.value(forHTTPHeaderField: "Mcp-Session-Id") == nil)
            #expect(body["params"]["protocolVersion"].string == "2025-06-18")
            return try rpc(body, result: .object(["protocolVersion": .string("2025-06-18")]))
        }
        #expect(request.value(forHTTPHeaderField: "Mcp-Session-Id") == "session")
        if body["method"].string == "notifications/initialized" { return (202, [:], Data()) }
        if body["method"].string == "tools/list" { return try rpc(body, result: .object(["tools": .array([])])) }
        return nil
    }
    @Test @MainActor func hostNormalization() throws {
        #expect(try T3Pairing.normalizeHost("fake.test").absoluteString == "https://fake.test")
        #expect(throws: T3PairingError.self) { try T3Pairing.normalizeHost("http://fake.test") }
        #expect(try T3Pairing.normalizeHost("http://localhost:123").port == 123)
    }
    @Test @MainActor func pairingPKCE() async throws {
        let challenge = Mutex("")
        let session = StubProtocol.session { request in
            switch request.url!.path {
            case "/.well-known/oauth-protected-resource": return try Self.json(.object(["resource": .string("https://fake.test/mcp"), "authorization_servers": .array([.string("https://fake.test")])]))
            case "/.well-known/oauth-authorization-server": return try Self.json(.object(["issuer": .string("https://fake.test"), "registration_endpoint": .string("https://fake.test/oauth/mcp/register"), "authorization_endpoint": .string("https://fake.test/oauth/mcp/authorize"), "token_endpoint": .string("https://fake.test/oauth/mcp/token"), "grant_types_supported": .array([.string("authorization_code")]), "code_challenge_methods_supported": .array([.string("S256")])]))
            case "/.well-known/t3/environment": return try Self.json(.object(["environmentId": .string("fake"), "serverVersion": .string("0.1.7-nightly.20261101.4016")]))
            case "/oauth/mcp/register":
                let body = try Self.body(request); #expect(body["client_name"].string == "Drawspeak (iPad)")
                #expect(body["redirect_uris"].array == [.string("http://127.0.0.1/drawspeak/oauth/callback")])
                return try Self.json(.object(["client_id": .string("a+b&c")]), status: 201)
            case "/oauth/mcp/decision":
                let body = try Self.body(request); challenge.withLock { $0 = body["authorization"]["code_challenge"].string! }
                #expect(body["decision"]["code"].string == "ABCDEFGHIJKL")
                let state = body["authorization"]["state"].string!
                return try Self.json(.object(["redirectTo": .string("http://127.0.0.1/drawspeak/oauth/callback?code=code&state=\(state)&iss=https%3A%2F%2Ffake.test")]))
            default:
                #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
                var data = request.httpBody ?? Data()
                if data.isEmpty, let stream = request.httpBodyStream { stream.open(); defer { stream.close() }; var buffer = [UInt8](repeating: 0, count: 4096); let n = stream.read(&buffer, maxLength: 4096); if n > 0 { data.append(contentsOf: buffer.prefix(n)) } }
                let form = String(decoding: data, as: UTF8.self)
                #expect(form.contains("client_id=a%2Bb%26c"))
                let fields = URLComponents(string: "https://fake.test/?" + form)!.queryItems!
                let verifier = fields.first { $0.name == "code_verifier" }!.value!
                let hash = Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
                #expect(hash == challenge.withLock { $0 })
                return try Self.json(.object(["access_token": .string("secret"), "token_type": .string("Bearer"), "scope": .string("orchestration:operate"), "expires_in": .number(2_592_000)]))
            }
        }
        let value = try await T3Pairing.pair(host: host, code: "abcdefghijkl", session: session)
        #expect(value.clientId == "a+b&c"); #expect(value.expiresAt > Date().addingTimeInterval(2_591_900))
    }
    @Test func sseAndSessionRecovery() async throws {
        let calls = Mutex(0)
        let session = StubProtocol.session { request in
            let body = try Self.body(request)
            if let reply = try Self.handshake(request, body) { return reply }
            let count = calls.withLock { $0 += 1; return $0 }
            if count == 1 { return (404, [:], Data()) }
            let reply = try JSONEncoder().encode(JSONValue.object(["id": body["id"], "result": .object(["structuredContent": .object(["threads": .array([])])])]))
            let sse = "data: {\"method\":\"notifications/progress\"}\n\ndata: " + String(decoding: reply, as: UTF8.self) + "\n\n"
            return (200, ["Content-Type": "text/event-stream"], Data(sse.utf8))
        }
        let result = try await MCPClient(credentials: credential(), session: session).callTool(name: "t3_thread_list")
        #expect(result["threads"].array.isEmpty); #expect(calls.withLock { $0 } == 2)
    }
    @Test(arguments: ["success", "running", "timeout", "uploadFailure", "unauthorized", "sessionExpired"])
    func delivery(_ scenario: String) async throws {
        let order = Mutex<[String]>([])
        let session = StubProtocol.session { request in
            if request.url!.path.hasPrefix("/api/") {
                order.withLock { $0.append("upload") }
                #expect(request.httpMethod == "POST"); #expect(request.value(forHTTPHeaderField: "Content-Length") == "3")
                return (scenario == "uploadFailure" ? 500 : 204, [:], Data())
            }
            let body = try Self.body(request)
            if let reply = try Self.handshake(request, body) { return reply }
            let name = body["params"]["name"].string!; order.withLock { $0.append(name) }
            var content: JSONValue = .object([:])
            switch name {
            case "t3_thread_read": content = .object(["thread": .object(["status": .string(scenario == "running" ? "running" : "idle"), "runtimeMode": .string("full-access")])])
            case "t3_attachment_prepare_upload":
                #expect(body["params"]["arguments"]["upload"]["sizeBytes"].int == 3)
                if scenario == "unauthorized" { return (401, [:], Data()) }
                content = .object(["attachmentId": .string(UUID().uuidString), "relativeUrl": .string("/api/attachments/upload/signed")])
            default:
                #expect(body["params"]["arguments"]["message"].string!.hasPrefix("[drawspeak-batch:"))
                #expect(body["params"]["arguments"]["attachments"].array.count == 2)
                if scenario == "timeout" { throw URLError(.timedOut) }
                if scenario == "sessionExpired" { return (404, [:], Data()) }
                content = .object(["messageId": .string("ack")])
            }
            return try Self.rpc(body, result: .object(["structuredContent": content]))
        }
        let service = T3ThreadService(client: MCPClient(credentials: credential(), session: session))
        let files = [OutgoingAttachment(fileName: "a.png", contentType: "image/png", data: Data([1,2,3])), OutgoingAttachment(fileName: "b.json", contentType: "application/json", data: Data([4,5,6]))]
        let progress = Mutex<[Int]>([])
        do {
            let ack = try await service.send(threadId: "thread", text: "Review", attachments: files) { done, total in #expect(total == 2); progress.withLock { $0.append(done) } }
            #expect(["success", "running"].contains(scenario)); #expect(ack.messageId == "ack")
        } catch {
            switch scenario {
            case "timeout": #expect(error == .outcomeUnknown)
            case "unauthorized": #expect(error == .notAuthorized)
            default: if case .notSent = error {} else { Issue.record("Expected notSent: \(error)") }
            }
        }
        let recorded = order.withLock { $0 }
        if ["success", "running", "timeout", "sessionExpired"].contains(scenario) {
            #expect(recorded == ["t3_thread_read", "t3_attachment_prepare_upload", "upload", "t3_attachment_prepare_upload", "upload", "t3_thread_send_attachments"])
            #expect(progress.withLock { $0 } == [1, 2])
        } else { #expect(!recorded.contains("t3_thread_send_attachments")) }
    }
    @Test func messagePaging() async throws {
        let session = StubProtocol.session { request in
            let body = try Self.body(request)
            if let reply = try Self.handshake(request, body) { return reply }
            let args = body["params"]["arguments"]
            let continuation = args["itemId"].string != nil, pageTwo = args["afterPosition"].int == 1
            if continuation { #expect(args["textOffset"].int == 5) }
            let item: JSONValue = .object(["itemId": .string(pageTwo ? "b" : "a"), "type": .string(pageTwo ? "user_message" : "assistant_message"), "text": .string(continuation ? " world" : pageTwo ? "Thanks" : "Hello"), "textTruncated": .bool(!continuation && !pageTwo), "nextTextOffset": continuation || pageTwo ? .null : .number(5)])
            return try Self.rpc(body, result: .object(["structuredContent": .object(["items": .array([item]), "nextPosition": .number(1), "hasMore": .bool(!pageTwo)])]))
        }
        let messages = try await T3ThreadService(client: MCPClient(credentials: credential(), session: session)).readMessages(threadId: "thread")
        #expect(messages.map(\.text) == ["Hello world", "Thanks"])
        #expect(messages.map(\.role) == ["assistant", "user"])
    }
    @Test func threadListPaging() async throws {
        let cursors = Mutex<[Int]>([])
        let session = StubProtocol.session { request in
            let body = try Self.body(request)
            if let reply = try Self.handshake(request, body) { return reply }
            let args = body["params"]["arguments"]
            #expect(args["allProjects"].bool); #expect(!args["includeSubagents"].bool); #expect(args["limit"].int == 100)
            let cursor = args["cursor"].int ?? 0; cursors.withLock { $0.append(cursor) }
            let thread: JSONValue = .object(["threadId": .string("t\(cursor)"), "title": .string("Thread"), "projectId": .string("p\(cursor)"), "projectTitle": .string("Project \(cursor)"), "status": .string("idle"), "updatedAt": .string("2026-11-04T12:00:00.000Z")])
            return try Self.rpc(body, result: .object(["structuredContent": .object(["threads": .array([thread]), "nextCursor": cursor < 400 ? .number(Double(cursor + 100)) : .null])]))
        }
        let threads = try await T3ThreadService(client: MCPClient(credentials: credential(), session: session)).listThreads()
        #expect(threads.count == 3); #expect(Set(threads.compactMap(\.projectId)).count == 3); #expect(threads.first?.updatedAt != nil)
        #expect(cursors.withLock { $0 } == [0, 100, 200])
    }
    @Test func validationHappensBeforeNetwork() async throws {
        let session = StubProtocol.session { _ in Issue.record("Invalid send reached network"); return (500, [:], Data()) }
        let service = T3ThreadService(client: MCPClient(credentials: credential(), session: session))
        do { _ = try await service.send(threadId: "t", text: "", attachments: [], progress: { _, _ in }); Issue.record("Expected validation failure") }
        catch { if case .notSent = error {} else { Issue.record("Incorrect failure") } }
    }
    @Test func reconcileQueuedSend() async throws {
        let session = StubProtocol.session { request in
            let body = try Self.body(request)
            if let reply = try Self.handshake(request, body) { return reply }
            let content: JSONValue = body["params"]["name"].string == "t3_queue" ? .object(["items": .array([.object(["text": .string("[drawspeak-batch:batch] Review")])])]) : .object(["items": .array([]), "hasMore": .bool(false)])
            return try Self.rpc(body, result: .object(["content": .array([.object(["type": .string("text"), "text": .string(String(decoding: try JSONEncoder().encode(content), as: UTF8.self))])])]))
        }
        let ack = try await T3ThreadService(client: MCPClient(credentials: credential(), session: session)).reconcile(threadId: "thread", batchId: "batch")
        #expect(ack != nil); #expect(ack?.messageId == nil)
    }

    @Test(arguments: ["user", "assistant", "prefix", "wrongProvenance", "failure"])
    func reconcileExactOutgoingMarker(_ scenario: String) async throws {
        let session = StubProtocol.session { request in
            let body = try Self.body(request)
            if let reply = try Self.handshake(request, body) { return reply }
            let isRead = body["params"]["name"].string == "t3_thread_read"
            if isRead && scenario == "failure" { return (500, [:], Data()) }
            let item: JSONValue = .object([
                "type": .string(scenario == "assistant" ? "assistant_message" : "user_message"),
                "createdBy": .string(scenario == "wrongProvenance" ? "user" : "agent"),
                "creationSource": .string("mcp"), "messageId": .string("sent"),
                "text": .string(scenario == "prefix" ? "[drawspeak-batch:ds-10] Review" : "[drawspeak-batch:ds-1] Review")
            ])
            return try Self.rpc(body, result: .object(["structuredContent": .object([
                "items": .array(isRead ? [item] : []), "hasMore": .bool(false)
            ])]))
        }
        let service: any ThreadService = T3ThreadService(client: MCPClient(credentials: credential(), session: session))
        #expect(service.hostURL == host)
        do {
            let ack = try await service.reconcile(threadId: "thread", batchId: "ds-1")
            #expect(scenario != "failure")
            if scenario == "user" { #expect(ack?.messageId == "sent") }
            else { #expect(ack == nil) }
        } catch {
            #expect(scenario == "failure")
        }
    }

    @Test(.enabled(if: KeychainProbe.isAvailable, "Needs Keychain access (not available to hostless simulator tests)")) @MainActor func reconnectUsesStoredCredential() async throws {
        let store = T3CredentialStore()
        #expect(store.save(credential()))
        defer { store.remove(host: host) }
        let unavailable = Mutex(true)
        let session = StubProtocol.session { request in
            #expect(request.url?.path == "/mcp")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fake-token")
            if request.httpMethod == "DELETE" { return (204, [:], Data()) }
            if unavailable.withLock({ $0 }) { throw URLError(.notConnectedToInternet) }
            let body = try Self.body(request)
            return try Self.handshake(request, body) ?? Self.rpc(body, result: .object([:]))
        }
        let previousHost = UserDefaults.standard.string(forKey: "drawspeak.t3.host")
        UserDefaults.standard.removeObject(forKey: "drawspeak.t3.host")
        defer { UserDefaults.standard.set(previousHost, forKey: "drawspeak.t3.host") }
        let connection = T3Connection(hostURL: host, session: session, store: store)
        await connection.restore()
        guard case .failed = connection.state else { Issue.record("Expected transient failure"); return }
        #expect(connection.credentials?.accessToken == "fake-token")
        #expect(connection.canReconnect)
        unavailable.withLock { $0 = false }
        await connection.reconnect()
        #expect(connection.state == .connected(host))
        #expect(connection.threadService != nil)
    }

    @Test(.enabled(if: KeychainProbe.isAvailable, "Needs Keychain access (not available to hostless simulator tests)")) @MainActor func unauthorizedReconnectRequiresPairing() async throws {
        let store = T3CredentialStore()
        #expect(store.save(credential()))
        defer { store.remove(host: host) }
        let calls = Mutex(0)
        let session = StubProtocol.session { _ in
            calls.withLock { $0 += 1 }
            return (401, [:], Data())
        }
        let previousHost = UserDefaults.standard.string(forKey: "drawspeak.t3.host")
        UserDefaults.standard.removeObject(forKey: "drawspeak.t3.host")
        defer { UserDefaults.standard.set(previousHost, forKey: "drawspeak.t3.host") }
        let connection = T3Connection(hostURL: host, session: session, store: store)
        await connection.restore()
        #expect(connection.state == .expired)
        #expect(!connection.canReconnect)
        await connection.reconnect()
        #expect(calls.withLock { $0 } == 1)
    }

    @Test(arguments: ["running", "waiting", "starting", "preparing", "completed", "idle", "unreachable"])
    func runningWarning(_ status: String) async throws {
        let session = StubProtocol.session { request in
            let body = try Self.body(request)
            if let reply = try Self.handshake(request, body) { return reply }
            if status == "unreachable" { throw URLError(.notConnectedToInternet) }
            return try Self.rpc(body, result: .object(["structuredContent": .object([
                "thread": .object(["status": .string(status)])
            ])]))
        }
        let running = await T3ThreadService(client: MCPClient(credentials: credential(), session: session)).isThreadRunning(threadId: "thread")
        #expect(running == ["running", "waiting", "starting", "preparing"].contains(status))
    }

}
