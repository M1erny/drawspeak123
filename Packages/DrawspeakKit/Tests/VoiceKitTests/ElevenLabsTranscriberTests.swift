import DrawspeakCore
import Foundation
import Testing
@testable import VoiceKit

struct ElevenLabsTranscriberTests {
    private let audio = Data("fake-audio-bytes".utf8)

    private func transcriber(_ stub: StubURLProtocol.Stub, key: String? = "test-key") -> ElevenLabsTranscriber {
        ElevenLabsTranscriber(keyStore: ElevenLabsKeyStore(fixedKey: key), session: stub.session, endpoint: stub.endpoint)
    }

    private func okBody(text: String = "Cześć", language: String = "pol", probability: Double = 0.98) -> Data {
        Data(#"{"language_code":"\#(language)","language_probability":\#(probability),"text":"\#(text)","words":[]}"#.utf8)
    }

    // MARK: Request

    @Test func sendsExactlyOneRequestWithExpectedFieldsAndHeader() async throws {
        let stub = StubURLProtocol.make(.response(status: 200, body: okBody()))
        let transcript = try await transcriber(stub).transcribe(audio: audio, contentType: "audio/mp4", language: "pl-PL")

        let sent = try #require(stub.requests.first)
        #expect(stub.requests.count == 1)
        #expect(sent.request.httpMethod == "POST")
        #expect(sent.request.value(forHTTPHeaderField: "xi-api-key") == "test-key")
        #expect(sent.request.timeoutInterval == 120)
        let contentType = try #require(sent.request.value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))

        let body = String(decoding: sent.body, as: UTF8.self)
        #expect(body.contains("name=\"file\"; filename=\"recording.m4a\"\r\nContent-Type: audio/mp4\r\n\r\nfake-audio-bytes\r\n"))
        for (name, value) in [("model_id", "scribe_v2"), ("language_code", "pol"), ("diarize", "false"),
                              ("tag_audio_events", "false"), ("timestamps_granularity", "word")] {
            #expect(body.contains("name=\"\(name)\"\r\n\r\n\(value)\r\n"))
        }
        #expect(transcript.requestedLanguage == "pol")
    }

    @Test func formOmitsLanguageCodeWhenAutomatic() {
        let body = String(decoding: ElevenLabsTranscriber.makeForm(audio: audio, contentType: "audio/mp4", language: nil).encoded(), as: UTF8.self)
        #expect(!body.contains("language_code"))
        #expect(body.contains("name=\"model_id\"\r\n\r\nscribe_v2\r\n"))
        #expect(body.hasSuffix("--\r\n"))
    }

    @Test func automaticLanguageSendsNoLanguageCode() async throws {
        let stub = StubURLProtocol.make(.response(status: 200, body: okBody(language: "eng")))
        let transcript = try await transcriber(stub).transcribe(audio: audio, contentType: "audio/mp4", language: nil)
        let body = String(decoding: try #require(stub.requests.first).body, as: UTF8.self)
        #expect(!body.contains("language_code"))
        #expect(transcript.requestedLanguage == nil)
        #expect(transcript.detectedLanguage == "eng")
    }

    @Test(arguments: [
        ("pl", "pol"), ("pl-PL", "pol"), ("pol", "pol"), ("PL_pl", "pol"),
        ("en", "eng"), ("en-US", "eng"), ("en-GB", "eng"), ("eng", "eng"),
    ])
    func mapsLanguages(input: String, expected: String) {
        #expect(ElevenLabsLanguage.code(for: input) == expected)
    }

    @Test(arguments: ["", "de", "fr-FR", "pl-POL", "pl-PL-x", "polish"])
    func rejectsUnknownLanguages(input: String) {
        #expect(ElevenLabsLanguage.code(for: input) == nil)
    }

    // MARK: Pre-request validation

    @Test func rejectsOversizedAudioWithoutRequest() async {
        let stub = StubURLProtocol.make(.response(status: 200, body: okBody()))
        let big = Data(count: 25 * 1024 * 1024 + 1)
        await expectFailure(.invalidRequest, processed: false) {
            try await transcriber(stub).transcribe(audio: big, contentType: "audio/mp4", language: nil)
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func acceptsAudioAtTheLimit() async throws {
        let stub = StubURLProtocol.make(.response(status: 200, body: okBody()))
        let atLimit = Data(count: 25 * 1024 * 1024)
        _ = try await transcriber(stub).transcribe(audio: atLimit, contentType: "audio/mp4", language: nil)
        #expect(stub.requests.count == 1)
    }

    @Test func rejectsEmptyAudioUnknownLanguageAndBadContentTypeWithoutRequest() async {
        let stub = StubURLProtocol.make(.response(status: 200, body: okBody()))
        let sut = transcriber(stub)
        await expectFailure(.invalidRequest, processed: false) {
            try await sut.transcribe(audio: Data(), contentType: "audio/mp4", language: nil)
        }
        await expectFailure(.invalidRequest, processed: false) {
            try await sut.transcribe(audio: audio, contentType: "audio/mp4", language: "de")
        }
        await expectFailure(.invalidRequest, processed: false) {
            try await sut.transcribe(audio: audio, contentType: "audio/mp4\r\nX-Evil: 1", language: nil)
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func withoutKeyIsNotConfiguredAndSendsNothing() async {
        let stub = StubURLProtocol.make(.response(status: 200, body: okBody()))
        let sut = transcriber(stub, key: nil)
        #expect(!sut.isConfigured)
        await expectFailure(.notConfigured, processed: false) {
            try await sut.transcribe(audio: audio, contentType: "audio/mp4", language: nil)
        }
        #expect(stub.requests.isEmpty)
        #expect(transcriber(stub).isConfigured)
    }

    // MARK: Status mapping

    @Test(arguments: [
        (401, TranscriptionFailure.Code.auth, false), (403, .auth, false),
        (429, .rateLimited, false),
        (400, .invalidRequest, false), (404, .invalidRequest, false), (422, .invalidRequest, false),
        (408, .invalidRequest, true),
        (500, .upstream, true), (503, .upstream, true),
        (302, .upstream, true),
    ])
    func mapsStatus(status: Int, code: TranscriptionFailure.Code, processed: Bool) {
        let failure = ElevenLabsTranscriber.failure(forStatus: status)
        #expect(failure.code == code)
        #expect(failure.requestMayHaveBeenProcessed == processed)
    }

    @Test func serverErrorSurfacesAsUpstreamAndIsNotRetried() async {
        let stub = StubURLProtocol.make(.response(status: 503, body: Data(#"{"detail":"secret-ish body"}"#.utf8)))
        await expectFailure(.upstream, processed: true) {
            try await transcriber(stub).transcribe(audio: audio, contentType: "audio/mp4", language: nil)
        }
        #expect(stub.requests.count == 1)
    }

    @Test func redirectIsNotFollowedAndFailsAsUpstream() async {
        let target = StubURLProtocol.makeTarget()
        let stub = StubURLProtocol.make(.redirect(to: target.endpoint))
        await expectFailure(.upstream, processed: true) {
            try await transcriber(stub).transcribe(audio: audio, contentType: "audio/mp4", language: nil)
        }
        #expect(target.requests.isEmpty)
    }

    @Test func transportErrorsMapToNetworkOrAborted() async {
        let offline = StubURLProtocol.make(.failure(.notConnectedToInternet))
        await expectFailure(.network, processed: true) {
            try await transcriber(offline).transcribe(audio: audio, contentType: "audio/mp4", language: nil)
        }
        let timedOut = StubURLProtocol.make(.failure(.timedOut))
        await expectFailure(.network, processed: true) {
            try await transcriber(timedOut).transcribe(audio: audio, contentType: "audio/mp4", language: nil)
        }
        let cancelled = StubURLProtocol.make(.failure(.cancelled))
        await expectFailure(.aborted, processed: true) {
            try await transcriber(cancelled).transcribe(audio: audio, contentType: "audio/mp4", language: nil)
        }
        #expect(ElevenLabsTranscriber.failure(forTransportError: CancellationError()).code == .aborted)
    }

    @Test func alreadyCancelledTaskAbortsBeforeTheRequest() async {
        let stub = StubURLProtocol.make(.response(status: 200, body: okBody()))
        let sut = transcriber(stub)
        let data = audio
        let task = Task { () -> TranscriptionFailure? in
            while !Task.isCancelled { await Task.yield() }
            do { _ = try await sut.transcribe(audio: data, contentType: "audio/mp4", language: nil); return nil } catch { return error as? TranscriptionFailure }
        }
        task.cancel()
        let failure = await task.value
        #expect(failure?.code == .aborted)
        #expect(failure?.requestMayHaveBeenProcessed == false)
        #expect(stub.requests.isEmpty)
    }

    // MARK: Response decoding

    @Test func decodesFullResponse() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let transcript = try ElevenLabsResponse.transcript(from: okBody(text: "Hello", language: "eng", probability: 0.5), requestedLanguage: "eng", receivedAt: now)
        #expect(transcript == Transcript(text: "Hello", requestedLanguage: "eng", detectedLanguage: "eng", languageProbability: 0.5,
                                         provider: "elevenlabs", modelId: "scribe_v2", receivedAt: now))
    }

    @Test func emptyTextIsAValidResult() throws {
        let transcript = try ElevenLabsResponse.transcript(from: okBody(text: ""), requestedLanguage: nil, receivedAt: .now)
        #expect(transcript.text.isEmpty)
        #expect(transcript.detectedLanguage == "pol")
    }

    @Test func missingOptionalFieldsDecode() throws {
        let transcript = try ElevenLabsResponse.transcript(from: Data(#"{"text":"x"}"#.utf8), requestedLanguage: nil, receivedAt: .now)
        #expect(transcript.detectedLanguage == nil)
        #expect(transcript.languageProbability == nil)
    }

    @Test(arguments: ["", "not json", "[]", #"{"language_code":"pol"}"#, #"{"text":5}"#, #"{"text":"x","language_probability":1.5}"#])
    func undecodableBodiesAreInvalidResponse(body: String) {
        do {
            _ = try ElevenLabsResponse.transcript(from: Data(body.utf8), requestedLanguage: nil, receivedAt: .now)
            Issue.record("expected failure")
        } catch {
            #expect(error.code == .invalidResponse)
            #expect(error.requestMayHaveBeenProcessed)
        }
    }

    // MARK: Helper

    private func expectFailure(
        _ code: TranscriptionFailure.Code,
        processed: Bool,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ body: () async throws -> Transcript
    ) async {
        do {
            _ = try await body()
            Issue.record("expected \(code) failure", sourceLocation: sourceLocation)
        } catch let error as TranscriptionFailure {
            #expect(error.code == code, sourceLocation: sourceLocation)
            #expect(error.requestMayHaveBeenProcessed == processed, sourceLocation: sourceLocation)
        } catch {
            Issue.record("unexpected error type", sourceLocation: sourceLocation)
        }
    }
}
