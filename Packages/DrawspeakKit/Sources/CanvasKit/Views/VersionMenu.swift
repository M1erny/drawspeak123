#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Version history and the selected version's change report.
struct VersionMenu: View {
    let lane: Lane
    let workspace: Workspace
    @State private var selectedId = ""

    var body: some View {
        if let selected = lane.selected {
            Group {
                if lane.key.isNow, lane.versions.count == 1, !isReturned(selected) {
                    Text("Now").font(.subheadline).foregroundStyle(Theme.secondaryInk)
                } else {
                    Menu {
                        Picker("Version", selection: $selectedId) {
                            ForEach(lane.versions.reversed()) { version in
                                Text(iterationLabel(version)).tag(version.id)
                            }
                        }
                        .pickerStyle(.inline)
                        Section("Changes") {
                            Text(selected.changeSummary ?? "No change summary supplied")
                            if !addressedComments(selected).isEmpty {
                                Text("Addressed comments: \(addressedComments(selected))")
                            }
                        }
                        if !lane.key.isNow || isReturned(selected) {
                            Button("Promote to Now", systemImage: "arrow.up.to.line") {
                                workspace.promoteToNow(selected.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(versionTitle(selected)).lineLimit(1)
                            Image(systemName: "chevron.down").imageScale(.small).accessibilityHidden(true)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .frame(minHeight: Theme.minTarget)
                        .contentShape(.rect)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.action)
                    .accessibilityLabel("\(lane.title) version and changes")
                    .accessibilityValue(versionTitle(selected))
                }
            }
            .onChange(of: selected.id, initial: true) { selectedId = selected.id }
            .onChange(of: selectedId) {
                guard !selectedId.isEmpty, selectedId != lane.selected?.id else { return }
                workspace.selectVersion(selectedId, lane: lane.key)
            }
        }
    }

    private func isReturned(_ snapshot: Snapshot) -> Bool {
        guard let canvas = workspace.currentCanvas else { return false }
        return CanvasLayout.isUnpromotedBaseline(snapshot, in: canvas)
    }

    private func versionTitle(_ snapshot: Snapshot) -> String {
        isReturned(snapshot) ? "Returned capture" : CanvasLabels.versionTitle(of: snapshot, in: lane)
    }

    private func iterationLabel(_ snapshot: Snapshot) -> String {
        var label = "\(versionTitle(snapshot)) · \(snapshot.capturedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))"
        if let summary = snapshot.changeSummary, !summary.isEmpty { label += " — \(summary)" }
        return label
    }

    private func addressedComments(_ snapshot: Snapshot) -> String {
        let ids = Set(snapshot.addressedNoteIds.compactMap(UUID.init(uuidString:)))
        return (workspace.currentCanvas?.notes ?? []).filter { ids.contains($0.id) }
            .map(\.ordinal).sorted().map { "#\($0)" }.joined(separator: ", ")
    }
}
#endif
