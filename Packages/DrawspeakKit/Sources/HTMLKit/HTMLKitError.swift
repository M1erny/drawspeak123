import Foundation

nonisolated public enum HTMLKitError: Error, Equatable, Sendable {
    /// No web view is attached or its document has not finished loading.
    case inspectorNotReady
    /// The probe returned something other than the expected JSON.
    case invalidProbeResponse
    /// The offline content rules could not be compiled; nothing is loaded without them.
    case contentRulesUnavailable
    /// The document failed to load.
    case loadFailed(String)
    /// The web content process ended before the work finished.
    case webContentTerminated
    case captureTimedOut
    case snapshotFailed
}
