import Foundation
import DrawspeakCore

public struct T3CredentialStore: Sendable {
    private let keychain = KeychainStore(service: "com.wydrox.drawspeak.t3")
    public init() {}
    @discardableResult public func save(_ credentials: T3Credentials) -> Bool {
        guard let data = try? JSONEncoder().encode(credentials) else { return false }
        return keychain.set(data, for: credentials.hostURL.absoluteString)
    }
    public func load(host: URL) -> T3Credentials? {
        guard let data = keychain.data(for: host.absoluteString) else { return nil }
        return try? JSONDecoder().decode(T3Credentials.self, from: data)
    }
    public func remove(host: URL) { keychain.remove(host.absoluteString) }
}
