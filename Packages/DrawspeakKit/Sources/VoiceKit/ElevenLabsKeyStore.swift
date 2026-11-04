import DrawspeakCore
import Foundation

/// The person's own ElevenLabs API key, kept in the iPad Keychain (ADR-0007).
/// The key is never logged, printed, exported or placed in an error.
nonisolated public struct ElevenLabsKeyStore: Sendable {
    public static let service = "com.wydrox.drawspeak.elevenlabs"
    public static let account = "api-key"

    private enum Source: Sendable {
        case keychain(KeychainStore)
        case fixed(String?)
    }

    private let source: Source

    public init() {
        source = .keychain(KeychainStore(service: Self.service))
    }

    /// Test-only: a store that holds a fixed key and never touches the Keychain.
    init(fixedKey: String?) {
        source = .fixed(fixedKey)
    }

    public var hasKey: Bool { key() != nil }

    /// For the transcriber only. Do not surface the value in UI or logs.
    func key() -> String? {
        let value: String? = switch source {
        case .keychain(let store): store.string(for: Self.account)
        case .fixed(let key): key
        }
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Trims whitespace and rejects an empty value. Returns false when nothing was saved.
    @discardableResult
    public func save(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, case .keychain(let store) = source else { return false }
        return store.set(trimmed, for: Self.account)
    }

    public func remove() {
        guard case .keychain(let store) = source else { return }
        store.remove(Self.account)
    }

    #if DEBUG && targetEnvironment(simulator)
    /// Simulator testing only: saves `DRAWSPEAK_ELEVENLABS_API_KEY` when it is set. Never prints it.
    public static func bootstrapFromEnvironment() {
        guard let value = ProcessInfo.processInfo.environment["DRAWSPEAK_ELEVENLABS_API_KEY"], !value.isEmpty else { return }
        ElevenLabsKeyStore().save(value)
    }
    #endif
}
