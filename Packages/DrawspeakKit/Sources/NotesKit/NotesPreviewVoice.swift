import Foundation
import DrawspeakCore

@MainActor
final class NotesPreviewVoice: VoiceCapturing {
    var isRecording = false
    var level: Double { 0.65 }
    var elapsed: TimeInterval { 12 }
    var hasPermission: Bool { true }
    func requestPermission() async -> Bool { true }
    func start(scope: RecordingScope, language: String?, onEvent: @escaping @MainActor (LiveTranscriptEvent) -> Void) throws { isRecording = true }
    func stop() -> CapturedAudio? { isRecording = false; return nil }
    func discard() { isRecording = false }
}
