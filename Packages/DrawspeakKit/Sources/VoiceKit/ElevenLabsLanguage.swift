import Foundation

/// Maps app and system language identifiers to the ISO 639-3 codes Scribe expects.
nonisolated enum ElevenLabsLanguage {
    /// "pol" or "eng" for accepted input ("pl", "pl-PL", "en-GB", ...); nil for anything else.
    static func code(for identifier: String) -> String? {
        let parts = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
        guard let language = parts.first, parts.count <= 2 else { return nil }
        if parts.count == 2, parts[1].count != 2 { return nil }
        return switch language {
        case "pl", "pol": "pol"
        case "en", "eng": "eng"
        default: nil
        }
    }
}
