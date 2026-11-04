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
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(thread.title).foregroundStyle(Theme.ink)
                                        Text(thread.projectTitle ?? thread.projectId ?? "Other threads")
                                            .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                                        if let updatedAt = thread.updatedAt {
                                            TimelineView(.periodic(from: .now, by: 60)) { context in
                                                Text(Self.recency(updatedAt, now: context.date))
                                                    .font(.caption).foregroundStyle(Theme.secondaryInk)
                                            }
                                        }
                                        if let status = Self.statusLabel(thread.status) {
                                            Text(status).font(.caption).foregroundStyle(Theme.secondaryInk)
                                                .padding(4).background(Theme.canvas, in: .capsule)
                                        }
                                    }
                                    Spacer()
                                    if selected?.threadId == thread.id && selected?.hostURL == service.hostURL {
                                        Image(systemName: "checkmark")
                                            .accessibilityLabel("Currently bound thread")
                                    }
                                }.frame(minHeight: 44, alignment: .leading)

                            }
                        }
                    }
                }
            }
            .overlay { if loading && threads.isEmpty { ProgressView("Loading threads") } else if filtered.isEmpty && error == nil { ContentUnavailableView(search.isEmpty ? "No threads" : "No matching threads", systemImage: "bubble.left.and.bubble.right", description: Text(search.isEmpty ? "Create a thread in T3 Code on your Mac." : "Try another thread title or project name.")) } }
            .searchable(text: $search, prompt: "Search threads or projects").refreshable { await load() }.task { await load() }
            .navigationTitle("Choose a thread").tint(Theme.action)
        }
    }
    private static func recency(_ date: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }
    private static func statusLabel(_ status: String?) -> String? {
        switch status {
        case "running", "preparing", "starting": "Running"
        case "waiting", "queued": "Waiting"
        case "failed": "Failed"
        default: nil
        }
    }
    private func load() async {
        guard !loading else { return }; loading = true; defer { loading = false }
        do { threads = try await service.listThreads(); error = nil } catch { self.error = error.localizedDescription }
    }
    private func pick(_ thread: ThreadSummary) { onPick(ThreadBinding(hostURL: service.hostURL, threadId: thread.id, threadTitle: thread.title, projectId: thread.projectId, projectTitle: thread.projectTitle)) }
}
