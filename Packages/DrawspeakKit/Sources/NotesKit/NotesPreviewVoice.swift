import Foundation
import DrawspeakCore

@MainActor
final class NotesPreviewVoice: VoiceCapturing {
    var isRecording = false
    var level: Double { 0.65 }
    var elapsed: TimeInterval { 12 }
    func requestPermission() async -> Bool { true }
    func start(scope: RecordingScope) throws { isRecording = true }
    func stop() -> CapturedAudio? { isRecording = false; return nil }
    func discard() { isRecording = false }
}
