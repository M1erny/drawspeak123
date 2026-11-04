import Foundation

/// Screens pushed inside Settings. Value-based so a pushed screen survives
/// the list rebuilding when the T3 connection state changes.
enum SettingsRoute: Hashable {
    case pairing
}
