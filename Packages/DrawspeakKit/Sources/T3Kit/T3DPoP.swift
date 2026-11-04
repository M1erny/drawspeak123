import CryptoKit
import Foundation

/// RFC 9449 DPoP proofs with an ephemeral P-256 key. T3 Code binds a token issued
/// with a proof to that key and limits it to one hour, so the pairing setup token
/// expires on its own once the key is gone.
nonisolated struct T3DPoP: Sendable {
    private let key = P256.Signing.PrivateKey()

    func proof(method: String, url: URL, accessToken: String? = nil, now: Date = .now) throws -> String {
        let point = key.publicKey.x963Representation
        let jwk: JSONValue = .object(["crv": .string("P-256"), "kty": .string("EC"),
                                      "x": .string(Self.base64url(point.subdata(in: 1..<33))), "y": .string(Self.base64url(point.subdata(in: 33..<65)))])
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        parts?.query = nil; parts?.fragment = nil
        var claims: [String: JSONValue] = ["htm": .string(method), "htu": .string(parts?.string ?? url.absoluteString),
                                           "iat": .number(now.timeIntervalSince1970.rounded(.down)), "jti": .string(UUID().uuidString)]
        if let accessToken { claims["ath"] = .string(Self.base64url(Data(SHA256.hash(data: Data(accessToken.utf8))))) }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let header = Self.base64url(try encoder.encode(JSONValue.object(["typ": .string("dpop+jwt"), "alg": .string("ES256"), "jwk": jwk])))
        let input = header + "." + Self.base64url(try encoder.encode(JSONValue.object(claims)))
        return input + "." + Self.base64url(try key.signature(for: Data(input.utf8)).rawRepresentation)
    }

    static func base64url(_ data: Data) -> String {
        data.base64EncodedString().replacing("+", with: "-").replacing("/", with: "_").replacing("=", with: "")
    }
}
