import DrawspeakCore
import Foundation

/// A file read from the importer, waiting for its place on the canvas.
struct PendingImport: Identifiable, Sendable {
    let id = UUID()
    /// The canvas that was current when the import started; the file goes there.
    var canvasId: UUID
    var fileName: String
    var suggestedTitle: String
    var kind: ArtifactKind
    var contentType: String
    var data: Data
    var pixelSize: (width: Int, height: Int)
    var viewport: Viewport?
    var capture: Data?
    var containsScripts: Bool
}
