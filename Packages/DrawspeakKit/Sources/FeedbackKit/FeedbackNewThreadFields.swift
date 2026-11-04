import SwiftUI

/// Project and title of the thread the send will start.
struct FeedbackNewThreadFields: View {
    @Bindable var model: FeedbackPreviewModel

    var body: some View {
        Group {
            if model.projects.isEmpty {
                LabeledContent {
                    if model.loadingProjects { ProgressView() }
                    else { Button(action: reload) { Text("Try Again", bundle: .module) } }
                } label: {
                    Text("Project", bundle: .module)
                    if let error = model.projectsError { Text(error) }
                }
            } else {
                Picker(selection: $model.newThreadProjectId) {
                    ForEach(model.projects) { project in
                        Text(project.title).tag(Optional(project.id))
                    }
                } label: { Text("Project", bundle: .module) }
            }
            LabeledContent {
                TextField(text: $model.newThreadTitle) { Text("Title", bundle: .module) }
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
            } label: { Text("Title", bundle: .module) }
        }
        .disabled(model.busy)
        .task { await model.loadProjects() }
    }

    private func reload() { Task { await model.loadProjects() } }
}
