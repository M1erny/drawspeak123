import Foundation

enum TranscriptionLanguage: String, CaseIterable, Identifiable {
    case automatic
    case polish
    case english

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .automatic: "Detect Automatically"
        case .polish: "Polish"
        case .english: "English"
        }
    }

    /// The ISO code sent to ElevenLabs, or nil for detection.
    var providerCode: String? {
        switch self {
        case .automatic: nil
        case .polish: "pol"
        case .english: "eng"
        }
    }
}
