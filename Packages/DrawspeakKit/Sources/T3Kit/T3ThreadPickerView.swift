import SwiftUI
import DrawspeakCore

public struct T3ThreadPickerView: View {
    private let service: T3ThreadService
    private let selected: ThreadBinding?
    private let onPick: (ThreadBinding) -> Void
    @State private var threads: [ThreadSummary] = []
    @State private var search = ""
    @State private var error: String?
    @State private var loading = false
    public init(service: T3ThreadService, selected: ThreadBinding? = nil, onPick: @escaping (ThreadBinding) -> Void) {
        self.service = service; self.selected = selected; self.onPick = onPick
    }
    private var groups: [String] { Array(Set(filtered.map { $0.projectId ?? "Other threads" })).sorted() }
    private var filtered: [ThreadSummary] { threads.filter { search.isEmpty || $0.title.localizedStandardContains(search) || ($0.projectTitle?.localizedStandardContains(search) ?? false) } }
    public var body: some View {
        NavigationStack {
            List {
                if let error {
                    Section { Text(error).foregroundStyle(Theme.annotation); Button("Try again", systemImage: "arrow.clockwise") { Task { await load() } }.frame(minHeight: 44) }
                }
                ForEach(groups, id: \.self) { project in
                    Section(filtered.first(where: { ($0.projectId ?? "Other threads") == project })?.projectTitle ?? project) {
                        ForEach(filtered.filter { ($0.projectId ?? "Other threads") == project }) { thread in
                            Button { pick(thread) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(thread.title).foregroundStyle(Theme.ink)
                                    if let status = thread.status { Text(status.replacingOccurrences(of: "_", with: " ").capitalized).font(.caption).foregroundStyle(Theme.secondaryInk).padding(4).background(Theme.canvas, in: .capsule) }
                                    if selected?.threadId == thread.id && selected?.hostURL == service.hostURL { Label("Selected", systemImage: "checkmark").font(.caption) }
                                }.frame(minHeight: 44, alignment: .leading)
                            }
                        }
                    }
                }
            }
            .overlay { if loading && threads.isEmpty { ProgressView("Loading threads") } else if filtered.isEmpty && error == nil { ContentUnavailableView(search.isEmpty ? "No threads" : "No matching threads", systemImage: "bubble.left.and.bubble.right", description: Text("Create a thread in T3 Code on your Mac.")) } }
            .searchable(text: $search, prompt: "Search threads or projects").refreshable { await load() }.task { await load() }
            .navigationTitle("Choose a thread").tint(Theme.action)
        }
    }
    private func load() async {
        guard !loading else { return }; loading = true; defer { loading = false }
        do { threads = try await service.listThreads(); error = nil } catch { self.error = error.localizedDescription }
    }
    private func pick(_ thread: ThreadSummary) { onPick(ThreadBinding(hostURL: service.hostURL, threadId: thread.id, threadTitle: thread.title, projectId: thread.projectId, projectTitle: thread.projectTitle)) }
}
