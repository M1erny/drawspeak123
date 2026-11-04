import DrawspeakCore
import Foundation

/// ElevenLabs Scribe v2 batch transcription: one multipart POST per recording, never retried automatically.
nonisolated public struct ElevenLabsTranscriber: Transcribing {
    public static let defaultEndpoint = URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!
    static let modelId = "scribe_v2"
    static let maxAudioBytes = 25 * 1024 * 1024
    static let timeout: TimeInterval = 120

    private let keyStore: ElevenLabsKeyStore
    private let session: URLSession
    private let endpoint: URL

    public init(
        keyStore: ElevenLabsKeyStore = .init(),
        session: URLSession? = nil,
        endpoint: URL = ElevenLabsTranscriber.defaultEndpoint
    ) {
        self.keyStore = keyStore
        self.session = session ?? URLSession(configuration: .ephemeral)
        self.endpoint = endpoint
    }

    public var isConfigured: Bool { keyStore.hasKey }

    public func transcribe(
        audio: Data,
        contentType: String,
        language: String?
    ) async throws(TranscriptionFailure) -> Transcript {
        guard let key = keyStore.key() else {
            throw Self.failure(.notConfigured, processed: false)
        }
        guard Self.isHeaderValue(key) else {
            throw Self.failure(.auth, processed: false)
        }
        guard !audio.isEmpty, audio.count <= Self.maxAudioBytes, Self.isHeaderValue(contentType) else {
            throw Self.failure(.invalidRequest, processed: false)
        }
        var requestedLanguage: String?
        if let language {
            guard let code = ElevenLabsLanguage.code(for: language) else {
                throw Self.failure(.invalidRequest, processed: false)
            }
            requestedLanguage = code
        }
        if Task.isCancelled {
            throw Self.failure(.aborted, processed: false)
        }

        let form = Self.makeForm(audio: audio, contentType: contentType, language: requestedLanguage)
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.httpShouldHandleCookies = false

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.upload(for: request, from: form.encoded(), delegate: NoRedirectDelegate())
        } catch {
            throw Self.failure(forTransportError: error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw Self.failure(.invalidResponse, processed: true)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.failure(forStatus: http.statusCode)
        }
        return try ElevenLabsResponse.transcript(from: data, requestedLanguage: requestedLanguage, receivedAt: .now)
    }

    // MARK: Internal, testable pieces

    /// `language` must already be normalized ("pol"/"eng") or nil for automatic detection.
    static func makeForm(audio: Data, contentType: String, language: String?) -> MultipartFormData {
        var form = MultipartFormData()
        form.addFile(name: "file", fileName: "recording.m4a", contentType: contentType, data: audio)
        form.addField(name: "model_id", value: modelId)
        if let language {
            form.addField(name: "language_code", value: language)
        }
        form.addField(name: "diarize", value: "false")
        form.addField(name: "tag_audio_events", value: "false")
        form.addField(name: "timestamps_granularity", value: "word")
        return form
    }

    /// Non-2xx responses. Error bodies are never read, so they cannot leak into diagnostics.
    static func failure(forStatus status: Int) -> TranscriptionFailure {
        let code: TranscriptionFailure.Code = switch status {
        case 401, 403: .auth
        case 429: .rateLimited
        case 400..<500: .invalidRequest
        default: .upstream
        }
        // A 4xx other than 408 was rejected before any work happened.
        let rejected = (400..<500).contains(status) && status != 408
        return failure(code, processed: !rejected)
    }

    static func failure(forTransportError error: any Error) -> TranscriptionFailure {
        if error is CancellationError || (error as? URLError)?.code == .cancelled || Task.isCancelled {
            return failure(.aborted, processed: true)
        }
        return failure(.network, processed: true)
    }

    private static func failure(_ code: TranscriptionFailure.Code, processed: Bool) -> TranscriptionFailure {
        TranscriptionFailure(code: code, requestMayHaveBeenProcessed: processed)
    }

    /// Printable ASCII only: blocks CR/LF injection into headers.
    private static func isHeaderValue(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { (0x20...0x7e).contains($0) }
    }
}
