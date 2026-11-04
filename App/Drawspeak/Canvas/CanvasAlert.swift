import Foundation

/// An error the person has to read: import, pull and storage failures.
struct CanvasAlert: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var message: String

    static func importFailed(_ message: String) -> CanvasAlert {
        CanvasAlert(title: String(localized: "Can't Import File"), message: message)
    }

    static func pullFailed(_ message: String) -> CanvasAlert {
        CanvasAlert(title: String(localized: "Can't Pull Versions"), message: message)
    }

    /// Pull found replies but no versions in them; `reason` says why.
    static func noVersions(_ reason: String) -> CanvasAlert {
        CanvasAlert(title: String(localized: "No versions found in the latest replies."), message: reason)
    }

    static func saveFailed(_ message: String) -> CanvasAlert {
        CanvasAlert(title: String(localized: "Can't Save Changes"), message: message)
    }
}
