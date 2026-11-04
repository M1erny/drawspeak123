import Foundation

/// Why `AudioRecorder.start(scope:)` could not begin capturing.
public enum AudioRecorderError: Error, Hashable, Sendable {
    case alreadyRecording
    case sessionUnavailable
    case recorderUnavailable
}
