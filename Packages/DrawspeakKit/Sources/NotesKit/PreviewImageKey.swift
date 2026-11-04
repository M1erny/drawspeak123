import Foundation
import DrawspeakCore

nonisolated struct PreviewImageKey: Hashable, Sendable {
    let url: URL?
    let crop: NRect
}
