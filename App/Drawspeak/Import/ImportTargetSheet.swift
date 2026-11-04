import DrawspeakCore
import SwiftUI

/// Where an imported file goes: a new screen, a new Now, or a proposal version.
struct ImportTargetSheet: View {
    let workspace: Workspace
    let pending: PendingImport
    let onChoose: (Workspace.ImportTarget) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newScreenTitle = ""
    @State private var choice: ImportChoice = .newScreen
    @State private var screens: [ScreenTargetModel] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("File", value: pending.fileName)
                    if pending.containsScripts {
                        Text("Scripts won't run.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("New Screen") {
                    ImportTargetRow(title: Text("New Screen"), isSelected: choice == .newScreen, action: chooseNewScreen)
                    TextField("Title", text: $newScreenTitle)
                        .disabled(choice != .newScreen)
                }
                ForEach(screens) { screen in
                    ScreenTargetSection(model: screen, choice: $choice)
                }
            }
            .navigationTitle("Add to Canvas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                }
            }
            .onAppear(perform: prepare)
            .onChange(of: workspace.canvas(pending.canvasId)) { _, canvas in screens = ScreenTargetModel.make(canvas) }
        }
        .tint(.primary)
        .presentationSizing(.form)
    }

    private func prepare() {
        newScreenTitle = pending.suggestedTitle
        screens = ScreenTargetModel.make(workspace.canvas(pending.canvasId))
    }

    private func chooseNewScreen() {
        choice = .newScreen
    }

    private func add() {
        switch choice {
        case .newScreen:
            let title = newScreenTitle.trimmingCharacters(in: .whitespaces)
            onChoose(.newScreen(title: title.isEmpty ? pending.suggestedTitle : title))
        case .existing(let target):
            onChoose(target)
        }
    }
}
