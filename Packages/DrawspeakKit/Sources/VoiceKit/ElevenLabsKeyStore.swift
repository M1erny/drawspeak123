import DrawspeakCore
import Foundation

/// The app's built-in ElevenLabs API key (ADR-0008), injected at build time into
/// Info.plist as `DSElevenLabsAPIKey`. People never enter a key.
/// The key is never logged, printed, exported or placed in an error.
nonisolated public struct ElevenLabsKeyStore: Sendable {
    public static let infoDictionaryKey = "DSElevenLabsAPIKey"
    /// The Keychain item used by builds that asked people for their own key.
    static let legacyService = "com.wydrox.drawspeak.elevenlabs"
    static let legacyAccount = "api-key"

    private let value: String?

    /// Reads the key from the main bundle. Simulator debug builds prefer
    /// `DRAWSPEAK_ELEVENLABS_API_KEY` from the environment when it is set.
    public init() {
        #if DEBUG && targetEnvironment(simulator)
        if let override = Self.sanitized(ProcessInfo.processInfo.environment["DRAWSPEAK_ELEVENLABS_API_KEY"]) {
            value = override
            return
        }
        #endif
        value = Self.sanitized(Bundle.main.object(forInfoDictionaryKey: Self.infoDictionaryKey) as? String)
    }

    /// Reads the key from an Info dictionary (tests and other bundles).
    init(infoDictionary: [String: Any]) {
        value = Self.sanitized(infoDictionary[Self.infoDictionaryKey] as? String)
    }

    /// Test-only: a store that holds a fixed key.
    init(fixedKey: String?) {
        value = Self.sanitized(fixedKey)
    }

    public var hasKey: Bool { value != nil }

    /// For the transcribers only. Do not surface the value in UI or logs.
    func key() -> String? { value }

    /// Deletes a key a person saved in an earlier build; the built-in key replaces it.
    public static func removeLegacyKeychainKey() {
        KeychainStore(service: legacyService).remove(legacyAccount)
    }

    /// Trimmed and non-empty; an unexpanded build setting such as `$(ELEVENLABS_API_KEY)` means no key.
    static func sanitized(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
