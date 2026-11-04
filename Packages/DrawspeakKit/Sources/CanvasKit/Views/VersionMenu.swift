#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Version history belongs to the lane title; single-version lanes have no menu.
struct VersionMenu: View {
    let lane: Lane
    let workspace: Workspace
    @State private var selectedId = ""
    @State private var model = VersionMenuModel()

    var body: some View {
        Menu {
            Picker(selection: $selectedId) {
                ForEach(model.entries) { entry in
                    VersionMenuRow(entry: entry).tag(entry.id)
                }
            } label: { Text("Version", bundle: .module) }
            .pickerStyle(.inline)
            if let summary = lane.selected?.changeSummary, !summary.isEmpty {
                Section {
                    Text(summary)
                    if !model.addressedComments.isEmpty {
                        Text("Addresses \(model.addressedComments)", bundle: .module, comment: "List of comment numbers addressed by this version.")
                    }
                } header: { Text("Changes", bundle: .module) }
            }
            if model.canPromote {
                Button(String(localized: "Promote to Now", bundle: .module), systemImage: "arrow.up.to.line", action: promote)
            }
        } label: {
            HStack(spacing: CanvasMetrics.spacing) {
                LaneTitle(lane: lane)
                Image(systemName: "chevron.down").imageScale(.small).accessibilityHidden(true)
            }
            .font(.headline)
            .frame(minHeight: Theme.minTarget)
        }
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .onChange(of: lane, initial: true, update)
        .onChange(of: workspace.currentCanvas, update)
        .onChange(of: selectedId, selectVersion)
    }
    private func update() {
        model.update(lane: lane, canvas: workspace.currentCanvas)
        selectedId = lane.selected?.id ?? ""
    }
    private func selectVersion() {
        guard !selectedId.isEmpty, selectedId != lane.selected?.id else { return }
        workspace.selectVersion(selectedId, lane: lane.key)
    }
    private func promote() {
        if let selected = lane.selected { workspace.promoteToNow(selected.id) }
    }
}
#endif
