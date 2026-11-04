import DrawspeakCore
import SwiftUI

struct CanvasActionsPalette: View {
    let hasThread: Bool
    let isPulling: Bool
    let isCompact: Bool
    let actions: CanvasChrome.Actions

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                Button("Import Image or HTML…", systemImage: "square.and.arrow.down", action: actions.importFile)
                Button("Pull Versions from Thread", systemImage: "arrow.down.circle", action: actions.pull)
                    .disabled(!hasThread || isPulling)
                Divider()
                Button("Add Region Without Drawing…", systemImage: "rectangle.dashed.badge.record", action: actions.addRegion)
            } label: {
                Group {
                    if isPulling {
                        ProgressView()
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .frame(width: Theme.minTarget, height: Theme.minTarget)
            }
            .accessibilityLabel("Add")
            .accessibilityValue(isPulling ? "Pulling versions" : "")

            Button("Comments", systemImage: "text.bubble", action: actions.showNotes)
                .labelStyle(.iconOnly)
                .frame(width: Theme.minTarget, height: Theme.minTarget)
                .keyboardShortcut("l", modifiers: [.command, .shift])

            Button("Drafts and Sent", systemImage: "tray.full", action: actions.showHistory)
                .labelStyle(.iconOnly)
                .frame(width: Theme.minTarget, height: Theme.minTarget)

            Button("Settings", systemImage: "gearshape", action: actions.showSettings)
                .labelStyle(.iconOnly)
                .frame(width: Theme.minTarget, height: Theme.minTarget)
                .keyboardShortcut(",", modifiers: .command)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 4)
        .paletteBackground()
    }
}
