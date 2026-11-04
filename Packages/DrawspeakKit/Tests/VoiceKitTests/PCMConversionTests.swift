import AVFoundation
import Foundation
import Testing
@testable import VoiceKit

struct PCMConversionTests {
    private func sine(format: AVAudioFormat, frames: AVAudioFrameCount, offset: Int) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for channel in 0..<Int(format.channelCount) {
            let samples = buffer.floatChannelData![channel]
            for index in 0..<Int(frames) {
                samples[index] = 0.5 * sin(2 * .pi * 440 * Float(offset + index) / Float(format.sampleRate))
            }
        }
        return buffer
    }

    @Test(arguments: [(48_000.0, 1 as AVAudioChannelCount), (44_100.0, 2), (16_000.0, 1)])
    func oneSecondBecomesAbout16000MonoInt16Samples(sampleRate: Double, channels: AVAudioChannelCount) throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels))
        let converter = try #require(PCMConverter(from: format))
        let framesPer100ms = AVAudioFrameCount(sampleRate / 10)
        var total = 0
        for step in 0..<10 {
            let data = converter.convert(sine(format: format, frames: framesPer100ms, offset: step * Int(framesPer100ms)))
            #expect(data.count % 2 == 0)
            total += data.count
        }
        // Resampling keeps a small look-ahead; nothing beyond one second appears.
        #expect(total <= 16_000 * 2)
        #expect(total >= 15_600 * 2)
    }

    @Test func emptyBufferProducesNoBytes() throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let converter = try #require(PCMConverter(from: format))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16))
        #expect(converter.convert(buffer).isEmpty)
    }

    @Test func chunkerEmits100msChunksAndKeepsTheRemainder() {
        var chunker = PCMChunker()
        #expect(chunker.append(Data(count: 3_000)).isEmpty)
        let chunks = chunker.append(Data(count: 7_000))
        #expect(chunks.map(\.count) == [3_200, 3_200, 3_200])
        #expect(chunker.flush().count == 400)
        #expect(chunker.flush().isEmpty)
    }

    @Test func averagePowerOfFullScaleSquareIsZeroDecibels() {
        let square = (0..<480).map { $0.isMultiple(of: 2) ? Float(1) : -1 }
        #expect(abs(CaptureSink.averagePower(square.span)) < 0.01)
        #expect(CaptureSink.averagePower([Float]().span) == -160)
        #expect(CaptureSink.averagePower([Float](repeating: 0, count: 10).span) == -160)
    }
}
