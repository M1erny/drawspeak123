import Foundation

/// Client frames for the ElevenLabs realtime speech-to-text WebSocket.
nonisolated enum RealtimeClientMessage {
    private struct AudioChunk: Encodable {
        let messageType = "input_audio_chunk"
        let audioBase64: String
        let commit: Bool
        let sampleRate: Int

        enum CodingKeys: String, CodingKey {
            case messageType = "message_type"
            case audioBase64 = "audio_base_64"
            case commit
            case sampleRate = "sample_rate"
        }
    }

    /// One JSON text frame carrying base64 PCM s16le mono at 16 kHz.
    static func audioChunk(_ pcm: Data, commit: Bool) -> String {
        let chunk = AudioChunk(audioBase64: pcm.base64EncodedString(), commit: commit, sampleRate: Int(PCMConverter.sampleRate))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Encoding strings, a Bool and an Int cannot fail.
        let data = (try? encoder.encode(chunk)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}

/// Server frames the app acts on.
nonisolated enum RealtimeServerMessage: Equatable {
    case sessionStarted
    case partial(String)
    case committed(String)
    /// Any error type; carries only the `message_type`, never the server's text.
    case error(type: String)
    /// Warnings, timestamped duplicates of committed text and unknown types.
    case ignored

    static let errorTypes: Set<String> = [
        "error", "auth_error", "quota_exceeded", "rate_limited", "input_error", "chunk_size_exceeded",
        "insufficient_audio_activity", "session_time_limit_exceeded", "transcriber_error", "invalid_request",
        "commit_throttled", "unaccepted_terms", "resource_exhausted", "queue_overflow",
    ]

    private struct Frame: Decodable {
        let messageType: String
        let text: String?

        enum CodingKeys: String, CodingKey {
            case messageType = "message_type"
            case text
        }
    }

    /// Nil when the frame is not a JSON object with a `message_type`.
    static func parse(_ text: String) -> RealtimeServerMessage? {
        guard let frame = try? JSONDecoder().decode(Frame.self, from: Data(text.utf8)) else { return nil }
        return switch frame.messageType {
        case "session_started": .sessionStarted
        case "partial_transcript": .partial(frame.text ?? "")
        case "committed_transcript": .committed(frame.text ?? "")
        case "committed_transcript_with_timestamps", "warning": .ignored
        case let type where errorTypes.contains(type) || type.hasSuffix("_error"): .error(type: type)
        default: .ignored
        }
    }
}
