import SwiftUI
import DrawspeakCore

/// Bindable views of `Workspace.commentSelection` for the Comments list.
extension Workspace {
    /// Select mode as the List's edit mode; leaving it clears the selection.
    var commentEditMode: EditMode {
        get { commentSelection == nil ? .inactive : .active }
        set { commentSelection = newValue.isEditing ? (commentSelection ?? []) : nil }
    }

    /// The picked comments; empty outside Select mode.
    var selectedComments: Set<UUID> {
        get { commentSelection ?? [] }
        set { commentSelection = newValue }
    }
}
