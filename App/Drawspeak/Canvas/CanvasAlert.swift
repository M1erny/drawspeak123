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

    static func saveFailed(_ message: String) -> CanvasAlert {
        CanvasAlert(title: String(localized: "Can't Save Changes"), message: message)
    }
}
