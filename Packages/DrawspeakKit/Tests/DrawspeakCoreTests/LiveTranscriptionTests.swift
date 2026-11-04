import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Live transcription (ADR-0008)")
struct LiveTranscriptionTests {
    private func recordingWorkspace(
        voice: FakeVoice = FakeVoice(), transcriber: FakeTranscriber = FakeTranscriber(text: "batch text")
    ) throws -> (Workspace, FakeVoice, FakeTranscriber) {
        let ws = makeWorkspace()
        ws.voice = voice
        ws.transcriber = transcriber
        try addImage(ws, id: "s1")
        return (ws, voice, transcriber)
    }

    @Test func subjectMarkStartsRecordingSynchronouslyWhenPermissionIsGranted() throws {
        let (ws, voice, _) = try recordingWorkspace()
        ws.transcriptionLanguage = { "pol" }
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        // No await: capture is already running when addNote returns.
        #expect(voice.startCount == 1)
        #expect(ws.activeRecording?.noteId == id)
        #expect(voice.lastLanguage == "pol")
        #expect(ws.note(id)?.recordings.map(\.state) == [.recording])
    }

    /// Owner decision (2026-11-04): every mark starts voice, arrows and strokes included.
    @Test func arrowStartsVoiceToo() throws {
        let (ws, voice, _) = try recordingWorkspace()
        let id = try #require(ws.addNote(snapshotId: "s1", shape: arrowShape, autoVoice: true))
        #expect(voice.startCount == 1)
        #expect(ws.activeRecording?.noteId == id)
    }

    @Test func firstUseAsksForPermissionThenStarts() async throws {
        let voice = FakeVoice()
        voice.hasPermission = false
        let (ws, _, _) = try recordingWorkspace(voice: voice)
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        #expect(voice.startCount == 0)
        #expect(await waitUntil { ws.activeRecording?.noteId == id })
        #expect(voice.startCount == 1)
    }

    @Test func deniedPermissionLeavesATextNote() async throws {
        let voice = FakeVoice()
        voice.hasPermission = false
        voice.permissionGranted = false
        let (ws, _, _) = try recordingWorkspace(voice: voice)
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        #expect(await waitUntil { ws.voiceIssue == .permissionDenied })
        #expect(ws.activeRecording == nil)
        #expect(ws.note(id)?.recordings.isEmpty == true)
    }

    @Test func textAppearsProgressivelyAndFinishedStoresTheLiveTranscript() async throws {
        let (ws, voice, transcriber) = try recordingWorkspace()
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        let scope = try #require(ws.activeRecording)

        voice.emit(.partial("Ten przy"))
        #expect(ws.livePartialText == "Ten przy")
        #expect(ws.liveText(for: id) == "Ten przy")
        #expect(ws.note(id)?.text == "")

        voice.emit(.committed("Ten przycisk."))
        #expect(ws.livePartialText == "")
        #expect(ws.note(id)?.text == "Ten przycisk.")
        #expect(ws.note(id)?.textSource == .transcript)

        voice.emit(.partial("powinien być"))
        // Committed text is already in the note: the live text shows only what is not.
        #expect(ws.liveText(for: id) == "powinien być")
        voice.emit(.committed("Powinien być niebieski."))
        #expect(ws.note(id)?.text == "Ten przycisk. Powinien być niebieski.")
        #expect(ws.note(id)?.recordings.first?.transcript?.text == "Ten przycisk. Powinien być niebieski.")

        ws.stopRecording()
        let saving = try #require(ws.note(id)?.recordings.first)
        #expect(saving.audio != nil)
        #expect(saving.state == .transcribing)
        #expect(ws.isTranscriptionInFlight(scope))

        voice.emit(.finished("Ten przycisk. Powinien być niebieski."))
        let done = try #require(ws.note(id)?.recordings.first)
        #expect(done.state == .transcribed)
        #expect(done.transcript?.provider == "elevenlabs")
        #expect(done.transcript?.modelId == "scribe_v2_realtime")
        #expect(ws.note(id)?.text == "Ten przycisk. Powinien być niebieski.")
        #expect(ws.liveText(for: id) == nil)
        #expect(!ws.isTranscriptionInFlight(scope))
        try await Task.sleep(for: .milliseconds(80))
        #expect(transcriber.calls == 0)
    }

    /// Device report (0.2.0): the comment showed "Są ręce… Bardzo źle to wygląda." twice.
    /// The editor shows `liveText(for:)` above the note text, so committed segments that
    /// were already added to the text must not be part of the live text.
    @Test func liveTextNeverRepeatsWhatIsAlreadyInTheNoteText() throws {
        let (ws, voice, _) = try recordingWorkspace()
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        voice.emit(.committed("Są ręce."))
        voice.emit(.committed("Bardzo źle to wygląda."))
        let text = try #require(ws.note(id)?.text)
        #expect(text == "Są ręce. Bardzo źle to wygląda.")
        // What the person sees: the live block, then the editor.
        let shown = [ws.liveText(for: id) ?? "", text].filter { !$0.isEmpty }.joined(separator: "\n")
        #expect(shown.components(separatedBy: "Bardzo źle to wygląda.").count == 2)
        #expect(ws.liveText(for: id) == nil)

        // Stopped, waiting for `finished`: still no repeat.
        ws.stopRecording()
        #expect(ws.liveText(for: id) == nil)
        voice.emit(.finished("Są ręce. Bardzo źle to wygląda."))
        #expect(ws.note(id)?.text == "Są ręce. Bardzo źle to wygląda.")
    }

    @Test func segmentsKeptOutOfTypedTextStayVisibleAsLiveText() throws {
        let (ws, voice, _) = try recordingWorkspace()
        let second = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        ws.updateNoteText(second, text: "Mine")
        voice.emit(.committed("Heard this."))
        voice.emit(.partial("and"))
        #expect(ws.note(second)?.text == "Mine")
        #expect(ws.liveText(for: second) == "Heard this. and")
    }

    @Test func typingDuringRecordingKeepsTheTypedTextAndStoresSegmentsOnTheRecording() async throws {
        let (ws, voice, transcriber) = try recordingWorkspace()
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        voice.emit(.committed("First words."))
        #expect(ws.note(id)?.text == "First words.")

        ws.updateNoteText(id, text: "My own words")
        voice.emit(.committed("More speech."))
        #expect(ws.note(id)?.text == "My own words")
        #expect(ws.note(id)?.textSource == .typed)
        #expect(ws.note(id)?.recordings.first?.transcript?.text == "First words. More speech.")

        voice.eventsAfterStop = [.finished("First words. More speech.")]
        ws.stopRecording()
        #expect(await waitUntil { ws.note(id)?.recordings.first?.state == .transcribed })
        #expect(ws.note(id)?.text == "My own words")
        #expect(transcriber.calls == 0)
    }

    @Test func typedTextBeforeRecordingIsNeverReplaced() async throws {
        let (ws, voice, _) = try recordingWorkspace()
        let id = addTextNote(ws, snapshotId: "s1", text: "Typed first")
        await ws.startRecording(noteId: id)
        voice.emit(.committed("Spoken."))
        #expect(ws.note(id)?.text == "Typed first")
        #expect(ws.note(id)?.recordings.first?.transcript?.text == "Spoken.")
    }

    @Test func liveFailureFallsBackToOneBatchTranscription() async throws {
        let (ws, voice, transcriber) = try recordingWorkspace()
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        let scope = try #require(ws.activeRecording)
        voice.emit(.partial("half"))
        voice.emit(.failed(code: "auth_error"))
        #expect(ws.livePartialText == "")
        // Recording continues; the fallback waits for Stop.
        #expect(ws.activeRecording == scope)
        #expect(transcriber.calls == 0)

        ws.stopRecording()
        #expect(await waitUntil { ws.note(id)?.recordings.first?.state == .transcribed })
        #expect(transcriber.calls == 1)
        #expect(ws.note(id)?.text == "batch text")
        // A late live event cannot trigger a second request.
        voice.emit(.failed(code: "network"))
        try await Task.sleep(for: .milliseconds(80))
        #expect(transcriber.calls == 1)
    }

    @Test func emptyLiveResultFallsBackToBatchOnce() async throws {
        let voice = FakeVoice()
        voice.eventsAfterStop = [.finished("")]
        let (ws, _, transcriber) = try recordingWorkspace(voice: voice)
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        ws.stopRecording()
        #expect(await waitUntil { ws.note(id)?.recordings.first?.state == .transcribed })
        try await Task.sleep(for: .milliseconds(80))
        #expect(transcriber.calls == 1)
        #expect(ws.note(id)?.text == "batch text")
    }

    @Test func batchFallbackReplacesPartialLiveText() async throws {
        let voice = FakeVoice()
        let (ws, _, transcriber) = try recordingWorkspace(voice: voice, transcriber: FakeTranscriber(text: "The whole sentence."))
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        voice.emit(.committed("The whole"))
        voice.emit(.failed(code: "transcriber_error"))
        ws.stopRecording()
        #expect(await waitUntil { ws.note(id)?.recordings.first?.state == .transcribed })
        #expect(ws.note(id)?.text == "The whole sentence.")
        #expect(transcriber.calls == 1)
    }

    @Test func lateEventsLandOnlyOnTheirOwnNote() async throws {
        let voice = FakeVoice()
        let (ws, _, _) = try recordingWorkspace(voice: voice)
        let first = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        let firstEvents = try #require(voice.onEvent)
        ws.stopRecording()

        let second = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        #expect(ws.focusedNoteId == second)
        firstEvents(.committed("For the first note."))
        firstEvents(.finished("For the first note."))
        #expect(ws.note(first)?.text == "For the first note.")
        #expect(ws.note(first)?.recordings.first?.state == .transcribed)
        #expect(ws.note(second)?.text == "")
        #expect(ws.livePartialText == "")
    }

    @Test func discardIgnoresLaterEvents() throws {
        let voice = FakeVoice()
        let (ws, _, _) = try recordingWorkspace(voice: voice)
        let id = addTextNote(ws, snapshotId: "s1", text: "keep")
        let events: @MainActor (LiveTranscriptEvent) -> Void
        do {
            _ = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
            events = try #require(voice.onEvent)
        }
        ws.discardRecording()
        events(.committed("ghost"))
        #expect(ws.note(id)?.text == "keep")
        #expect(ws.currentCanvas?.notes.contains { $0.text.contains("ghost") } == false)
    }

    @Test func deletedNoteIsNotRecreatedByLateLiveEvents() async throws {
        let voice = FakeVoice()
        let (ws, _, _) = try recordingWorkspace(voice: voice)
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        let events = try #require(voice.onEvent)
        ws.stopRecording()
        ws.deleteNote(id)
        events(.committed("late"))
        events(.finished("late"))
        #expect(ws.note(id) == nil)
    }

    @Test func secondRecordingStartsANewLine() async throws {
        let voice = FakeVoice()
        let (ws, _, _) = try recordingWorkspace(voice: voice)
        let id = try #require(ws.addNote(snapshotId: "s1", shape: regionShape, autoVoice: true))
        voice.emit(.committed("One."))
        voice.eventsAfterStop = [.finished("One.")]
        ws.stopRecording()
        #expect(await waitUntil { ws.note(id)?.recordings.first?.state == .transcribed })

        voice.eventsAfterStop = []
        await ws.startRecording(noteId: id)
        voice.emit(.committed("Two."))
        #expect(ws.note(id)?.text == "One.\nTwo.")
    }
}
