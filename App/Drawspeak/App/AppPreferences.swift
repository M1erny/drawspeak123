import Foundation

/// UserDefaults keys shared by `@AppStorage` and the workspace closures.
enum AppPreferences {
    static let autoVoice = "drawspeak.autoVoice"
    static let drawWithFinger = "drawspeak.drawWithFinger"
    static let transcriptionLanguage = "drawspeak.transcriptionLanguage"
    static let refineWithClaude = "drawspeak.refineWithClaude"
    static let pullFollowUpsAdditive = "drawspeak.pullFollowUpsAdditive"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            pullFollowUpsAdditive: true,
            autoVoice: true,
            drawWithFinger: false,
            refineWithClaude: true,
            transcriptionLanguage: TranscriptionLanguage.automatic.rawValue,
        ])
    }
}
