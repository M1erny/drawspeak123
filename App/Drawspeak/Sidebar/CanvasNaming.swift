import DrawspeakCore
import Foundation

enum CanvasNaming {
    static func nextTitle(in workspace: Workspace) -> String {
        String(localized: "Review \(workspace.canvases.count + 1)",
               comment: "Default title of a new canvas; the number distinguishes review canvases.")
    }
}
