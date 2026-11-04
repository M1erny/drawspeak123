import Foundation
import CryptoKit
import Security

public enum T3Pairing {
    public static let redirectURI = "http://127.0.0.1/drawspeak/oauth/callback"
    public static func normalizeHost(_ input: String) throws(T3PairingError) -> URL {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var parts = URLComponents(string: value.contains("://") ? value : "https://" + value),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil, parts.path.isEmpty || parts.path == "/",
              parts.scheme == "https" || (parts.scheme == "http" && ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host)) else { throw .invalidHost }
        parts.path = ""
        guard let url = parts.url else { throw .invalidHost }; return url
    }
    public static func pair(host: URL, code: String, accessLevel: String = "full-access", session: URLSession = .shared) async throws(T3PairingError) -> T3Credentials {
        do {
            let origin = try normalizeHost(host.absoluteString)
            let resource = try await request(origin.appending(path: ".well-known/oauth-protected-resource"), session: session)
            guard let server = resource["authorization_servers"].array.first?.string.flatMap(URL.init(string:)),
                  let resourceName = resource["resource"].string else { throw T3PairingError.invalidResponse }
            let metadata = try await request(server.appending(path: ".well-known/oauth-authorization-server"), session: session)
            guard metadata["grant_types_supported"].array.contains(.string("authorization_code")),
                  metadata["code_challenge_methods_supported"].array.contains(.string("S256")),
                  let issuer = metadata["issuer"].string,
                  let registration = metadata["registration_endpoint"].string.flatMap(URL.init(string:)),
                  let tokenURL = metadata["token_endpoint"].string.flatMap(URL.init(string:)),
                  let authorizationURL = metadata["authorization_endpoint"].string.flatMap(URL.init(string:)) else { throw T3PairingError.invalidResponse }
            // Refuse metadata that could move a pairing code or token to another origin.
            for url in [server, registration, tokenURL, authorizationURL] {
                guard url.scheme == origin.scheme, url.host == origin.host, url.port == origin.port else { throw T3PairingError.invalidResponse }
            }
            let environment = try await request(origin.appending(path: ".well-known/t3/environment"), session: session)
            let endpoint = T3Endpoint(origin: origin, issuer: issuer, resource: resourceName, environmentId: environment["environmentId"].string, serverVersion: environment["serverVersion"].string)
            let client = try await request(registration, body: .object(["client_name": .string("Drawspeak (iPad)"), "redirect_uris": .array([.string(redirectURI)])]), session: session)
            guard let clientId = client["client_id"].string else { throw T3PairingError.invalidResponse }
            let verifier = try random(32), state = try random(24)
            let challenge = base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
            let started = Date.now
            let decisionURL = authorizationURL.deletingLastPathComponent().appending(path: "decision")
            let decision = try await request(decisionURL, body: .object([
                "authorization": .object(["response_type": .string("code"), "client_id": .string(clientId), "redirect_uri": .string(redirectURI), "code_challenge": .string(challenge), "code_challenge_method": .string("S256"), "state": .string(state), "resource": .string(resourceName)]),
                "decision": .object(["_tag": .string("pairing-code"), "access": .string(accessLevel), "code": .string(code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())])
            ]), session: session, approval: true)
            guard let redirect = decision["redirectTo"].string.flatMap(URLComponents.init(string:)) else { throw T3PairingError.invalidResponse }
            let query = redirect.queryItems ?? []
            func value(_ key: String) -> String? { query.first { $0.name == key }?.value }
            guard value("state") == state, value("iss") == issuer,
                  redirect.scheme == "http", redirect.host == "127.0.0.1", redirect.path == "/drawspeak/oauth/callback" else { throw T3PairingError.invalidResponse }
            if value("error") != nil { throw T3PairingError.approvalRejected(value("error_description") ?? String(localized: "T3 Code rejected the authorization request.", bundle: .module)) }
            guard let authCode = value("code") else { throw T3PairingError.invalidResponse }
            guard Date.now.timeIntervalSince(started) < 60 else { throw T3PairingError.expired }
            let fields = ["grant_type": "authorization_code", "code": authCode, "redirect_uri": redirectURI, "client_id": clientId, "code_verifier": verifier, "resource": resourceName]
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
            let form = fields.sorted { $0.key < $1.key }.map { $0.key + "=" + ($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "") }.joined(separator: "&")
            let token = try await request(tokenURL, form: form, session: session)
            guard let accessToken = token["access_token"].string, let seconds = token["expires_in"].int, seconds > 0,
                  token["token_type"].string?.lowercased() == "bearer", let scope = token["scope"].string else { throw T3PairingError.invalidResponse }
            return T3Credentials(hostURL: origin, clientId: clientId, accessToken: accessToken, scope: scope, expiresAt: Date.now.addingTimeInterval(Double(seconds)), accessLevel: accessLevel, endpoint: endpoint)
        } catch let error as T3PairingError { throw error }
        catch { throw .unreachable }
    }
    private static func request(_ url: URL, body: JSONValue? = nil, form: String? = nil, session: URLSession, approval: Bool = false) async throws -> JSONValue {
        var request = URLRequest(url: url); request.timeoutInterval = 60; request.httpShouldHandleCookies = false
        if let body { request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONEncoder().encode(body) }
        if let form { request.httpMethod = "POST"; request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type"); request.httpBody = Data(form.utf8) }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw T3PairingError.invalidResponse }
        if approval && response.statusCode == 400 {
            if let reason = (try? JSONDecoder().decode(JSONValue.self, from: data))?["message"].string { throw T3PairingError.approvalRejected(reason) }
            throw T3PairingError.codeRejected
        }
        if response.statusCode == 400, (try? JSONDecoder().decode(JSONValue.self, from: data))?["error"].string == "invalid_grant" { throw T3PairingError.expired }
        guard (200..<300).contains(response.statusCode) else { throw T3PairingError.serverError(response.statusCode) }
        guard let value = try? JSONDecoder().decode(JSONValue.self, from: data) else { throw T3PairingError.invalidResponse }; return value
    }
    private static func random(_ count: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else { throw T3PairingError.invalidResponse }
        return base64url(Data(bytes))
    }
    private static func base64url(_ data: Data) -> String { data.base64EncodedString().replacing("+", with: "-").replacing("/", with: "_").replacing("=", with: "") }
}
