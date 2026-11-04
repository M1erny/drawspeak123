import SwiftUI
import DrawspeakCore

struct CommentRefinementStatus: View {
    let workspace: Workspace
    let note: Note
    @State private var showsOriginal = false

    var body: some View {
        if let refinement = note.refinement {
            Group {
                switch refinement.state {
                case .refining:
                    Label { Text("Refining…", bundle: .module) } icon: { Image(systemName: "sparkles") }
                        .foregroundStyle(.secondary)
                case .refined:
                    if refinement.text == note.trimmedText {
                        Menu {
                            Button(action: showOriginal) { Text("Show Original", bundle: .module) }
                        } label: {
                            Label { Text("Refined", bundle: .module) } icon: { Image(systemName: "sparkles") }
                        }
                        .frame(minHeight: Theme.minTarget)
                    } else {
                        Button(action: useRefinedText) { Text("Use Refined Text", bundle: .module) }
                            .frame(minHeight: Theme.minTarget)
                    }
                case .failed:
                    HStack {
                        Text("Refine failed", bundle: .module).foregroundStyle(.secondary)
                        Button(action: retry) { Text("Retry", bundle: .module) }
                            .frame(minHeight: Theme.minTarget)
                    }
                }
            }
            .font(.caption)
            .sheet(isPresented: $showsOriginal) {
                OriginalCommentSheet(text: refinement.rawText)
            }
        }
    }

    private func showOriginal() { showsOriginal = true }
    private func useRefinedText() { workspace.useRefinedText(noteId: note.id) }
    private func retry() { workspace.refine(noteId: note.id) }
}
