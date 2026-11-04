@preconcurrency import AVFoundation
import Foundation

/// Converts captured buffers to 16 kHz mono signed 16-bit little-endian PCM, the
/// format the realtime transcriber expects. Not thread-safe: use from one thread.
nonisolated final class PCMConverter {
    static let sampleRate = 16_000.0
    // 16 kHz mono Int16 is always a valid format.
    static let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: true)!

    private let converter: AVAudioConverter
    private let inputFormat: AVAudioFormat

    init?(from inputFormat: AVAudioFormat) {
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              let converter = AVAudioConverter(from: inputFormat, to: Self.outputFormat) else { return nil }
        converter.downmix = true
        self.converter = converter
        self.inputFormat = inputFormat
    }

    /// Converts one buffer; the converter keeps resampling state between calls.
    func convert(_ buffer: AVAudioPCMBuffer) -> Data {
        guard buffer.frameLength > 0 else { return Data() }
        let ratio = Self.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: Self.outputFormat, frameCapacity: capacity) else { return Data() }
        // The input block runs synchronously inside `convert`, on this thread.
        nonisolated(unsafe) var supplied = false
        nonisolated(unsafe) let input = buffer
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return input
        }
        guard status != .error, output.frameLength > 0, let samples = output.int16ChannelData else { return Data() }
        return Data(bytes: samples[0], count: Int(output.frameLength) * MemoryLayout<Int16>.size)
    }
}

/// Groups PCM bytes into fixed-size chunks (100 ms at 16 kHz mono Int16 by default).
nonisolated struct PCMChunker {
    static let defaultChunkBytes = 3_200
    let chunkBytes: Int
    private var pending = Data()

    init(chunkBytes: Int = defaultChunkBytes) {
        self.chunkBytes = chunkBytes
    }

    /// Returns every complete chunk now available.
    mutating func append(_ data: Data) -> [Data] {
        pending.append(data)
        var chunks: [Data] = []
        while pending.count >= chunkBytes {
            chunks.append(Data(pending.prefix(chunkBytes)))
            pending = Data(pending.dropFirst(chunkBytes))
        }
        return chunks
    }

    /// The remainder (shorter than one chunk, possibly empty).
    mutating func flush() -> Data {
        defer { pending = Data() }
        return pending
    }
}
