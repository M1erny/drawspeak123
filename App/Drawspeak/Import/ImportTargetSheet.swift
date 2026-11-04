import DrawspeakCore
import SwiftUI

/// Where an imported file goes: a new screen, a new Now, or a proposal iteration.
struct ImportTargetSheet: View {
    let workspace: Workspace
    let pending: PendingImport
    let onChoose: (Workspace.ImportTarget) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newScreenTitle = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("File", value: pending.fileName)
                    LabeledContent("Size", value: "\(pending.pixelSize.width) × \(pending.pixelSize.height) px")
                    if pending.containsScripts {
                        Text("Scripts in this HTML do not run. Drawspeak shows it as a static mockup.")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
                Section("New Screen") {
                    TextField("Screen title", text: $newScreenTitle)
                    Button("Add as New Screen", systemImage: "rectangle.badge.plus") {
                        let title = newScreenTitle.trimmingCharacters(in: .whitespaces)
                        onChoose(.newScreen(title: title.isEmpty ? pending.suggestedTitle : title))
                    }
                }
                ForEach(workspace.currentCanvas?.screens ?? []) { screen in
                    ScreenTargetSection(workspace: workspace, screen: screen, onChoose: onChoose)
                }
            }
            .navigationTitle("Add to Canvas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { newScreenTitle = pending.suggestedTitle }
        }
    }
}
