@preconcurrency import AVFoundation
import Foundation
import Synchronization

/// Receives input-tap buffers on the audio thread: writes the original audio to the
/// local AAC file, feeds 100 ms PCM chunks to the live session and tracks the level.
nonisolated final class CaptureSink: Sendable {
    private struct State {
        var file: AVAudioFile?
        var converter: PCMConverter
        var chunker = PCMChunker()
        var frames: AVAudioFramePosition = 0
        var level: Double = 0
        var writeFailed = false
        var finished = false
    }

    private let state: Mutex<State>
    private let audio: AsyncStream<AudioChunk>.Continuation
    let sampleRate: Double

    init(file: sending AVAudioFile, converter: sending PCMConverter, sampleRate: Double, audio: AsyncStream<AudioChunk>.Continuation) {
        state = Mutex(State(file: file, converter: converter))
        self.audio = audio
        self.sampleRate = sampleRate
    }

    /// The tap provider, built outside any actor so it never asserts main-actor isolation on the audio thread.
    func makeTapProvider() -> @Sendable (AVReadOnlyAudioPCMBuffer, AVAudioTime) -> Void {
        { [self] buffer, _ in process(buffer) }
    }

    func process(_ buffer: AVReadOnlyAudioPCMBuffer) {
        guard buffer.frameLength > 0 else { return }
        let power: Float = switch buffer.channelData(0) {
        case .float(let samples): Self.averagePower(samples)
        default: -160
        }
        let chunks: [Data] = state.withLock { state in
            guard !state.finished else { return [] }
            if let file = state.file {
                do { try file.write(from: buffer) } catch { state.writeFailed = true }
            }
            state.frames += AVAudioFramePosition(buffer.frameLength)
            state.level = AudioRecorder.normalizedLevel(averagePower: power)
            return state.chunker.append(state.converter.convert(AVAudioPCMBuffer(copying: buffer)))
        }
        for chunk in chunks { audio.yield(AudioChunk(data: chunk, isLast: false)) }
    }

    /// Captured duration in seconds and the current level 0...1.
    var meters: (elapsed: TimeInterval, level: Double) {
        state.withLock { (Double($0.frames) / sampleRate, $0.level) }
    }

    /// Closes the file and sends the remainder as the final chunk (with the commit).
    /// Returns false when the file could not be written. Safe to call more than once.
    @discardableResult
    func finish() -> Bool {
        let (remainder, failed, first): (Data, Bool, Bool) = state.withLock { state in
            guard !state.finished else { return (Data(), state.writeFailed, false) }
            state.finished = true
            state.file?.close()
            state.file = nil
            state.level = 0
            return (state.chunker.flush(), state.writeFailed, true)
        }
        if first {
            // An empty final chunk still needs audio: 10 ms of silence carries the commit.
            let data = remainder.isEmpty ? Data(count: 320) : remainder
            audio.yield(AudioChunk(data: data, isLast: true))
            audio.finish()
        }
        return !failed
    }

    /// Stops feeding the live session without a final commit (discard).
    func cancel() {
        state.withLock { state in
            state.finished = true
            state.file?.close()
            state.file = nil
        }
        audio.finish()
    }

    /// RMS in dBFS.
    static func averagePower(_ samples: Span<Float>) -> Float {
        let count = samples.count
        guard count > 0 else { return -160 }
        var sum: Float = 0
        for index in samples.indices { sum += samples[index] * samples[index] }
        let rms = (sum / Float(count)).squareRoot()
        return rms > 0 ? 20 * log10(rms) : -160
    }
}
