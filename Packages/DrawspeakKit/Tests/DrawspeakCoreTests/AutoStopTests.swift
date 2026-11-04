import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Auto-stop: new mark and silence")
struct AutoStopTests {
    private func setUp() throws -> (Workspace, FakeVoice, TestClock) {
        let ws = makeWorkspace()
        let voice = FakeVoice()
        let clock = TestClock()
        ws.voice = voice
        ws.transcriber = FakeTranscriber(text: "batch")
        ws.now = { clock.date }
        ws.silenceCheckInterval = .milliseconds(5)
        try addImage(ws, id: "s1")
        return (ws, voice, clock)
    }

    /// Lets the silence monitor run a few checks.
    private func tick() async throws { try await Task.sleep(for: .milliseconds(40)) }

    @Test(arguments: [
        AnnotationShape.region(NRect(x: 0.5, y: 0.5, width: 0.2, height: 0.2)),
        .ellipse(NRect(x: 0.5, y: 0.5, width: 0.2, height: 0.2)),
        .lasso([NPoint(x: 0.5, y: 0.5), NPoint(x: 0.7, y: 0.5), NPoint(x: 0.6, y: 0.8)]),
        .arrow(from: NPoint(x: 0.1, y: 0.1), to: NPoint(x: 0.6, y: 0.6)),
        .stroke([NPoint(x: 0.1, y: 0.1), NPoint(x: 0.3, y: 0.4), NPoint(x: 0.5, y: 0.2)]),
    ])
    func everyNewMarkStopsTheActiveRecording(shape: AnnotationShape) throws {
        let (ws, _, _) = try setUp()
        let first = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        #expect(ws.activeRecording?.noteId == first)
        _ = try #require(ws.addNote(snapshotId: "s1", shape: shape, autoVoice: false))
        #expect(ws.activeRecording == nil)
        let recording = try #require(ws.note(first)?.recordings.first)
        #expect(recording.state != .recording)
        #expect(recording.audio != nil)
    }

    @Test func stopsAfterTheTimeoutWithoutSpeech() async throws {
        let (ws, _, clock) = try setUp()
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        clock.advance(9.5)
        try await tick()
        #expect(ws.activeRecording?.noteId == id)
        clock.advance(0.5)
        #expect(await waitUntil { ws.activeRecording == nil })
        #expect(ws.note(id)?.recordings.first?.audio != nil)
    }

    @Test func liveTextCountsAsSpeech() async throws {
        let (ws, voice, clock) = try setUp()
        ws.silenceTimeout = .seconds(5)
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        clock.advance(4)
        voice.emit(.partial("Ten"))
        clock.advance(4)
        try await tick()
        #expect(ws.activeRecording?.noteId == id)
        voice.emit(.committed("Ten przycisk."))
        clock.advance(4.9)
        try await tick()
        #expect(ws.activeRecording?.noteId == id)
        clock.advance(0.1)
        #expect(await waitUntil { ws.activeRecording == nil })
    }

    @Test func inputLevelAboveTheThresholdCountsAsSpeech() async throws {
        let (ws, voice, clock) = try setUp()
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        voice.level = 0.5
        for _ in 0..<4 {
            clock.advance(5)
            try await tick()
        }
        #expect(ws.activeRecording?.noteId == id)
        // Room noise below -40 dBFS is silence.
        voice.level = Workspace.speechLevelThreshold - 0.05
        clock.advance(9)
        try await tick()
        #expect(ws.activeRecording?.noteId == id)
        clock.advance(1)
        #expect(await waitUntil { ws.activeRecording == nil })
    }

    @Test func interruptedCaptureIsLeftForThePerson() async throws {
        let (ws, voice, clock) = try setUp()
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        voice.halted = true
        clock.advance(60)
        try await tick()
        #expect(ws.activeRecording?.noteId == id)
    }

    @Test func manualStopEndsTheMonitor() async throws {
        let (ws, _, clock) = try setUp()
        let first = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        ws.stopRecording()
        // A new recording gets its own full timeout.
        clock.advance(8)
        await ws.startRecording(noteId: first)
        clock.advance(8)
        try await tick()
        #expect(ws.activeRecording?.noteId == first)
    }
}
