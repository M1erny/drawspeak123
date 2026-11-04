import Testing
@testable import VoiceKit

@MainActor
struct AudioRecorderTests {
    @Test func levelMapsDecibelsToUnitRange() {
        #expect(AudioRecorder.normalizedLevel(averagePower: 0) == 1)
        #expect(AudioRecorder.normalizedLevel(averagePower: 6) == 1)
        #expect(AudioRecorder.normalizedLevel(averagePower: -50) == 0)
        #expect(AudioRecorder.normalizedLevel(averagePower: -160) == 0)
        #expect(AudioRecorder.normalizedLevel(averagePower: -25) == 0.5)
        #expect(AudioRecorder.normalizedLevel(averagePower: -.infinity) == 0)
    }

    @Test func idleRecorderHasNothingToStop() {
        let recorder = AudioRecorder()
        #expect(recorder.isRecording == false)
        #expect(recorder.level == 0)
        #expect(recorder.elapsed == 0)
        #expect(recorder.stop() == nil)
        recorder.discard()
        #expect(recorder.isRecording == false)
    }
}
