import DrawspeakCore
import Foundation

/// Where an imported file goes; a new screen gets its title at confirmation.
enum ImportChoice: Hashable {
    case newScreen
    case existing(Workspace.ImportTarget)
}
