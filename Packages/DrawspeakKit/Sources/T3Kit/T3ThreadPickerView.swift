import SwiftUI
import DrawspeakCore

public struct T3ThreadPickerView: View {
    private let service: T3ThreadService
    private let selected: ThreadBinding?
    private let onPick: (ThreadBinding) -> Void
    @State private var model = ThreadPickerModel()

    public init(service: T3ThreadService, selected: ThreadBinding? = nil, onPick: @escaping (ThreadBinding) -> Void) {
        self.service = service
        self.selected = selected
        self.onPick = onPick
    }

    public var body: some View {
        @Bindable var model = model
        List {
            if let error = model.error {
                ThreadPickerErrorRow(message: error, onRetry: retry)
            }
            ForEach(model.groups) { group in
                Section {
                    ForEach(group.threads) { thread in
                        ThreadPickerRow(
                            thread: thread,
                            isSelected: selected?.threadId == thread.id && selected?.hostURL == service.hostURL,
                            onPick: pick
                        )
                    }
                } header: {
                    Text(verbatim: group.title)
                }
            }
        }
        .overlay {
            ThreadPickerEmptyState(
                loading: model.loading,
                isEmpty: model.groups.isEmpty,
                isSearching: !model.search.isEmpty,
                hasError: model.error != nil
            )
        }
        .searchable(text: $model.search)
        .refreshable { await model.load(service: service, force: true) }
        .task(id: service.hostURL) { await load() }
        .navigationTitle(Text("Choose Thread", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .status) {
                HStack(spacing: 6) {
                    if model.refreshing {
                        ProgressView().controlSize(.small)
                            .accessibilityLabel(Text("Updating Threads", bundle: .module))
                    }
                    if let fetchedAt = model.fetchedAt {
                        Text("Updated \(Text(fetchedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated)))", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .tint(.primary)
    }

    private func load() async {
        await model.load(service: service)
    }

    private func retry() {
        Task { await model.load(service: service, force: true) }
    }

    private func pick(_ thread: ThreadSummary) {
        onPick(ThreadBinding(hostURL: service.hostURL, threadId: thread.id, threadTitle: thread.title,
                             projectId: thread.projectId, projectTitle: thread.projectTitle))
    }
}
