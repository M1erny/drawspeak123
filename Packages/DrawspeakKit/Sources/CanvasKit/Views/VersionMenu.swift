#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// "Iteration 2 ▾": the versions of a lane with their dates, newest first,
/// and Promote to Now for proposals.
struct VersionMenu: View {
    let lane: Lane
    let workspace: Workspace

    var body: some View {
        if let selected = lane.selected {
            Menu {
                Picker("Version", selection: selection(current: selected.id)) {
                    ForEach(lane.versions.reversed()) { version in
                        let title = CanvasLabels.versionTitle(of: version, in: lane)
                        Text("\(title) · \(version.capturedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                            .tag(version.id)
                    }
                }
                .pickerStyle(.inline)
                if !lane.key.isNow {
                    Divider()
                    Button("Promote to Now", systemImage: "arrow.up.to.line") {
                        workspace.promoteToNow(selected.id)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(CanvasLabels.versionTitle(of: selected, in: lane))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
                .font(.subheadline)
                .padding(.horizontal, 10)
                .frame(minHeight: Theme.minTarget)
                .contentShape(.rect)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .foregroundStyle(Theme.action)
            .accessibilityLabel("\(lane.title) version")
            .accessibilityValue(CanvasLabels.versionTitle(of: selected, in: lane))
        }
    }

    private func selection(current: String) -> Binding<String> {
        Binding(
            get: { current },
            set: { workspace.selectVersion($0, lane: lane.key) }
        )
    }
}
#endif
