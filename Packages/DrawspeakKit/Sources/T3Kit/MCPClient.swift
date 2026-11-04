import Foundation

public actor MCPClient {
    public nonisolated let credentials: T3Credentials
    private let session: URLSession
    private var sessionId: String?
    private var nextId = 0
    private var deliveryAttempts: [String: T3DeliveryAttempt] = [:]
    public func deliveryAttempt(threadId: String) -> T3DeliveryAttempt? { deliveryAttempts[threadId] }
    func recordAttempt(_ attempt: T3DeliveryAttempt) { deliveryAttempts[attempt.threadId] = attempt }
    private var initialization: Task<Void, any Error>?
    public init(credentials: T3Credentials, session: URLSession = .shared) { self.credentials = credentials; self.session = session }
    public func initialize() async throws(MCPError) {
        do {
            if let initialization { try await initialization.value; return }
            let task = Task { try await self.handshake() }
            initialization = task
            defer { initialization = nil }
            try await task.value
        } catch let error as MCPError { throw error } catch { throw .transport }
    }
    private func handshake() async throws {
        sessionId = nil
        let (value, response) = try await rpc(method: "initialize", params: .object([
            "protocolVersion": .string("2025-06-18"), "capabilities": .object([:]),
            "clientInfo": .object(["name": .string("Drawspeak"), "version": .string(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")])
        ]))
        guard value["protocolVersion"].string == "2025-06-18", let id = response.value(forHTTPHeaderField: "Mcp-Session-Id"), !id.isEmpty else { throw MCPError.invalidResponse }
        sessionId = id
        do {
            _ = try await rpc(method: "notifications/initialized", params: nil, notification: true)
            _ = try await rpc(method: "tools/list", params: .object([:]))
        } catch { sessionId = nil; throw error }
    }
    public func callTool(name: String, arguments: JSONValue = .object([:])) async throws(MCPError) -> JSONValue {
        do {
            if sessionId == nil || initialization != nil { try await initialize() }
            let result: JSONValue
            do { result = try await rpc(method: "tools/call", params: .object(["name": .string(name), "arguments": arguments])).0 }
            catch MCPError.http(404) {
                sessionId = nil
                guard ["t3_thread_list", "t3_thread_read", "t3_thread_search", "t3_project_list", "t3_project_read"].contains(name) else { throw MCPError.http(404) }
                try await initialize()
                result = try await rpc(method: "tools/call", params: .object(["name": .string(name), "arguments": arguments])).0
            }
            let content = result["structuredContent"] != .null ? result["structuredContent"] : result["content"].array.first?["text"].string.flatMap { try? JSONDecoder().decode(JSONValue.self, from: Data($0.utf8)) } ?? .null
            if result["isError"].bool { throw MCPError.tool(code: content["code"].string ?? "unknown", message: content["message"].string ?? String(localized: "T3 Code rejected the request.", bundle: .module)) }
            guard content != .null else { throw MCPError.invalidResponse }; return content
        } catch let error as MCPError { throw error } catch { throw .transport }
    }
    private func rpc(method: String, params: JSONValue?, notification: Bool = false) async throws -> (JSONValue, HTTPURLResponse) {
        nextId += 1; let id = JSONValue.number(Double(nextId))
        var body: [String: JSONValue] = ["jsonrpc": .string("2.0"), "method": .string(method)]
        if !notification { body["id"] = id }; if let params { body["params"] = params }
        var request = URLRequest(url: credentials.hostURL.appending(path: "mcp"))
        request.httpMethod = "POST"; request.httpShouldHandleCookies = false; request.timeoutInterval = 60
        request.setValue("Bearer " + credentials.accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if let sessionId { request.setValue(sessionId, forHTTPHeaderField: "Mcp-Session-Id"); request.setValue("2025-06-18", forHTTPHeaderField: "MCP-Protocol-Version") }
        request.httpBody = try JSONEncoder().encode(JSONValue.object(body))
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw MCPError.invalidResponse }
        if response.statusCode == 401 { throw MCPError.unauthorized }
        guard (200..<300).contains(response.statusCode) else { throw MCPError.http(response.statusCode) }
        if notification { return (.null, response) }
        let messages: [JSONValue]
        if response.value(forHTTPHeaderField: "Content-Type")?.lowercased().contains("text/event-stream") == true {
            let text = String(decoding: data, as: UTF8.self).replacing("\r\n", with: "\n")
            messages = text.components(separatedBy: "\n\n").compactMap { event in
                let payload = event.components(separatedBy: "\n").filter { $0.hasPrefix("data:") }.map { String($0.dropFirst(5)).trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
                return try? JSONDecoder().decode(JSONValue.self, from: Data(payload.utf8))
            }
        } else { messages = [try JSONDecoder().decode(JSONValue.self, from: data)] }
        guard let message = messages.first(where: { $0["id"] == id }) else { throw MCPError.invalidResponse }
        if message["error"] != .null { throw MCPError.rpc(code: message["error"]["code"].int ?? -1, message: message["error"]["message"].string ?? String(localized: "JSON-RPC error", bundle: .module)) }
        guard message["result"] != .null else { throw MCPError.invalidResponse }
        return (message["result"], response)
    }
    public func upload(data: Data, relativeURL: String, contentType: String) async throws(MCPError) {
        guard relativeURL.hasPrefix("/api/attachments/upload/"), !relativeURL.contains(".."),
              let url = URL(string: relativeURL, relativeTo: credentials.hostURL)?.absoluteURL,
              url.host == credentials.hostURL.host, url.scheme == credentials.hostURL.scheme, url.port == credentials.hostURL.port else { throw .invalidResponse }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.httpShouldHandleCookies = false; request.timeoutInterval = 60
        request.httpBody = data; request.setValue(contentType, forHTTPHeaderField: "Content-Type"); request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
        do {
            let (_, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw MCPError.invalidResponse }
            if response.statusCode == 401 { throw MCPError.unauthorized }
            guard (200..<300).contains(response.statusCode) else { throw MCPError.http(response.statusCode) }
        } catch let error as MCPError { throw error } catch { throw .transport }
    }
    public func close() async {
        guard let sessionId else { return }; self.sessionId = nil
        var request = URLRequest(url: credentials.hostURL.appending(path: "mcp")); request.httpMethod = "DELETE"; request.httpShouldHandleCookies = false
        request.setValue("Bearer " + credentials.accessToken, forHTTPHeaderField: "Authorization"); request.setValue(sessionId, forHTTPHeaderField: "Mcp-Session-Id")
        _ = try? await session.data(for: request)
    }
}
