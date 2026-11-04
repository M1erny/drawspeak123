import Foundation

/// One pairing code for both credentials (docs/T3-MCP-CONTRACT.md, "Workspace file access").
///
/// 1. The user's code is exchanged at `POST /oauth/token` (RFC 8693) with a DPoP proof for a
///    setup token holding `access:write`, the MCP scopes and `filesystem:read`. A DPoP-bound
///    token lives one hour and is useless without the in-memory key, so it is never stored.
/// 2. The setup token mints two one-time codes at `POST /api/auth/pairing-token`: one carrying
///    the MCP scopes for the approval decision, one carrying `orchestration:read filesystem:read`.
/// 3. The second code is exchanged (Bearer) for the 30-day read-only files token.
extension T3Pairing {
    static let filesScopes = ["orchestration:read", "filesystem:read"]

    /// The scopes T3 Code gives an MCP client session at each access level.
    static func mcpScopes(_ access: String) -> [String] {
        switch access {
        case "read-only": ["orchestration:read"]
        case "full-access": ["orchestration:read", "orchestration:operate", "settings:write", "source-control:write"]
        default: ["orchestration:read", "orchestration:operate"]
        }
    }

    enum SetupResult: Equatable {
        /// Codes minted from the user's code: one for the MCP approval, one (optional) for files.
        case minted(approvalCode: String, filesCode: String?)
        /// The server has no token exchange (or refused DPoP before using the code): approve with the user's code.
        case unsupported
    }

    static func setUp(origin: URL, code: String, accessLevel: String, session: URLSession) async throws(T3PairingError) -> SetupResult {
        let dpop = T3DPoP()
        let tokenURL = origin.appending(path: "oauth/token")
        let wanted = ["access:write"] + mcpScopes(accessLevel) + filesScopes
        let scopes = wanted.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        do { request.setValue(try dpop.proof(method: "POST", url: tokenURL), forHTTPHeaderField: "DPoP") } catch { return .unsupported }
        request.httpBody = Data(form([
            "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange", "subject_token": code,
            "subject_token_type": "urn:t3:params:oauth:token-type:environment-bootstrap",
            "requested_token_type": "urn:ietf:params:oauth:token-type:access_token",
            "scope": scopes.joined(separator: " "), "client_label": "Drawspeak (iPad) setup",
            "client_device_type": "tablet", "client_os": "iPadOS",
        ]).utf8)
        let (status, body) = try await send(request, session: session)
        switch status {
        case 200: break
        case 401 where body["dpopFailureReason"].string != nil: return .unsupported
        case 401, 403: throw .codeRejected
        case 400: throw .approvalRejected(String(localized: "That pairing code cannot grant Drawspeak's access. Create a code with the standard scopes.", bundle: .module))
        case 500...: throw .serverError(status)
        default: return .unsupported
        }
        guard let setupToken = body["access_token"].string, body["token_type"].string == "DPoP", let granted = body["scope"].string else { throw .invalidResponse }
        let held = Set(granted.split(separator: " ").map(String.init))
        guard held.contains("access:write"), mcpScopes(accessLevel).allSatisfy(held.contains) else {
            throw .approvalRejected(String(localized: "That pairing code was used but cannot grant this access level. Create a new code with the standard scopes.", bundle: .module))
        }
        func mint(_ scopes: [String], label: String) async throws(T3PairingError) -> String {
            let url = origin.appending(path: "api/auth/pairing-token")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("DPoP " + setupToken, forHTTPHeaderField: "Authorization")
            do {
                request.setValue(try dpop.proof(method: "POST", url: url, accessToken: setupToken), forHTTPHeaderField: "DPoP")
                request.httpBody = try JSONEncoder().encode(JSONValue.object(["label": .string(label), "scopes": .array(scopes.map(JSONValue.string))]))
            } catch { throw .invalidResponse }
            let (status, body) = try await send(request, session: session)
            guard status == 200, let credential = body["credential"].string else { throw status >= 500 ? .serverError(status) : .invalidResponse }
            return credential
        }
        let approval = try await mint(mcpScopes(accessLevel), label: "Drawspeak (iPad)")
        let files = held.contains("filesystem:read") ? (try? await mint(filesScopes, label: "Drawspeak (iPad) files")) : nil
        return .minted(approvalCode: approval, filesCode: files)
    }

    /// Exchanges a minted files code for the read-only Bearer files token. Nil on any failure:
    /// the MCP credential still works, and Pull then asks to pair again for file downloads.
    static func exchangeFilesCode(origin: URL, code: String, session: URLSession) async -> (token: String, expiresAt: Date)? {
        var request = URLRequest(url: origin.appending(path: "oauth/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(form([
            "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange", "subject_token": code,
            "subject_token_type": "urn:t3:params:oauth:token-type:environment-bootstrap",
            "requested_token_type": "urn:ietf:params:oauth:token-type:access_token",
            "scope": filesScopes.joined(separator: " "), "client_label": "Drawspeak (iPad) files",
            "client_device_type": "tablet", "client_os": "iPadOS",
        ]).utf8)
        guard let (status, body) = try? await send(request, session: session), status == 200,
              let token = body["access_token"].string, body["token_type"].string?.lowercased() == "bearer",
              let seconds = body["expires_in"].int, seconds > 0,
              Set((body["scope"].string ?? "").split(separator: " ").map(String.init)).contains("filesystem:read") else { return nil }
        return (token, Date.now.addingTimeInterval(Double(seconds)))
    }

    static func form(_ fields: [String: String]) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return fields.sorted { $0.key < $1.key }.map { $0.key + "=" + ($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "") }.joined(separator: "&")
    }

    private static func send(_ request: URLRequest, session: URLSession) async throws(T3PairingError) -> (Int, JSONValue) {
        var request = request
        request.timeoutInterval = 60; request.httpShouldHandleCookies = false
        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: request) } catch { throw .unreachable }
        guard let http = response as? HTTPURLResponse else { throw .invalidResponse }
        return (http.statusCode, (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .null)
    }
}
