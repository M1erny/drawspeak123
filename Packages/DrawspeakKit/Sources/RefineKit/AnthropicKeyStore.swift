import Foundation

/// Release builds obtain their key from the application's build-time configuration.
public nonisolated struct AnthropicKeyStore: Sendable {
    private let key: String?

    public init() {
        var candidate = Bundle.main.object(forInfoDictionaryKey: "DSAnthropicAPIKey") as? String
        #if DEBUG && targetEnvironment(simulator)
        if let override = ProcessInfo.processInfo.environment["DRAWSPEAK_ANTHROPIC_API_KEY"] {
            candidate = override
        }
        #endif
        self.init(fixedKey: candidate)
    }

    internal init(fixedKey: String?) {
        let cleaned = fixedKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        key = cleaned.isEmpty || cleaned.hasPrefix("$(") ? nil : cleaned
    }

    public var hasKey: Bool { key != nil }
    internal var apiKey: String? { key }
}
