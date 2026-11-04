import Foundation

/// UserDefaults keys shared by `@AppStorage` and the workspace closures.
enum AppPreferences {
    static let autoVoice = "drawspeak.autoVoice"
    static let drawWithFinger = "drawspeak.drawWithFinger"
    static let transcriptionLanguage = "drawspeak.transcriptionLanguage"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            autoVoice: true,
            drawWithFinger: false,
            transcriptionLanguage: TranscriptionLanguage.automatic.rawValue,
        ])
    }
}
