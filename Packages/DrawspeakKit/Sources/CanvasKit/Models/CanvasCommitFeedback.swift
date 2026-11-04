import Foundation
import Observation

/// Changes only on successful commits; drawing samples do not invalidate feedback views.
@Observable
final class CanvasCommitFeedback {
    var noteId: UUID?
}
