import DrawspeakCore
import SwiftUI

/// The Rename Canvas alert, driven by the canvas being renamed.
struct RenameCanvasAlert: ViewModifier {
    let workspace: Workspace
    @Binding var canvas: ReviewCanvas?
    @State private var title = ""

    func body(content: Content) -> some View {
        content
            .alert("Rename Canvas", item: $canvas) { canvas in
                TextField("Title", text: $title)
                Button("Cancel", role: .cancel) {}
                Button("Rename") { rename(canvas) }
            }
            .onChange(of: canvas) { _, canvas in title = canvas?.title ?? "" }
    }

    private func rename(_ canvas: ReviewCanvas) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        workspace.renameCanvas(canvas.id, title: trimmed)
    }
}
