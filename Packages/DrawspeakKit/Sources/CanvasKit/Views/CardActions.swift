#if canImport(UIKit)
import Foundation

/// Gesture-free card actions, offered to VoiceOver and Switch Control.
struct CardActions {
    /// `nil` hides Add Region.
    var addRegion: ((String) -> Void)?
    var selectComponent: (String) -> Void
    var showComments: (String) -> Void
}
#endif
