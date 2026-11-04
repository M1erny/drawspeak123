import Foundation

/// Classifies the notes of one canvas for the Feedback (N) package.
public struct FeedbackScope: Sendable {
    public var ready: [Note]
    public var unavailable: [(note: Note, reason: String)]
    public var pending: [Note]
    public var sent: [Note]

    /// N on the Feedback button: ready, unsent notes (including ones whose source needs repair).
    public var count: Int { ready.count + unavailable.count }

    /// Shown for HTML notes whose snapshot has no capture image yet.
    public static let captureMissingReason = "Preview image is still being created"

    public static func readiness(of note: Note, in canvas: ReviewCanvas, sourceAvailable: (Snapshot) -> Bool) -> NoteReadiness {
        if note.isRecording { return .recording }
        if note.isTranscribing && !note.hasText { return .transcribing }
        guard note.hasText else { return .markOnly }
        if note.isSentAtCurrentRevision { return .sent }
        guard note.shape.isValid else { return .sourceUnavailable("Mark is not valid") }
        guard let snapshot = canvas.snapshots.first(where: { $0.id == note.snapshotId }) else {
            return .sourceUnavailable("Snapshot is missing")
        }
        if let target = note.domTarget, target.snapshotId != snapshot.id || target.sourceHash != snapshot.html?.sha256 {
            return .sourceUnavailable("Component target does not match this version")
        }
        guard sourceAvailable(snapshot) else { return .sourceUnavailable("Source file is missing") }
        if snapshot.needsCapture { return .sourceUnavailable(Self.captureMissingReason) }
        return .ready
    }

    public init(canvas: ReviewCanvas, sourceAvailable: (Snapshot) -> Bool) {
        var ready: [Note] = []
        var unavailable: [(Note, String)] = []
        var pending: [Note] = []
        var sent: [Note] = []
        for note in canvas.notes.sorted(by: { $0.ordinal < $1.ordinal }) {
            switch Self.readiness(of: note, in: canvas, sourceAvailable: sourceAvailable) {
            case .ready: ready.append(note)
            case .sourceUnavailable(let reason): unavailable.append((note, reason))
            case .markOnly, .recording, .transcribing: pending.append(note)
            case .sent: sent.append(note)
            }
        }
        self.ready = ready
        self.unavailable = unavailable.map { (note: $0.0, reason: $0.1) }
        self.pending = pending
        self.sent = sent
    }
}
