import SwiftUI
import DrawspeakCore

struct ThreadPickerRow: View {
    let thread: ThreadSummary
    let isSelected: Bool
    let onPick: (ThreadSummary) -> Void

    var body: some View {
        Button(action: pick) {
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        Text(verbatim: thread.title)
                            .lineLimit(1)
                        if let status = statusLabel {
                            Text(status)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let updatedAt = thread.updatedAt {
                        Text("\(projectTitle) · \(Text(updatedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated)))", bundle: .module)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(verbatim: projectTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.primary)
            .frame(minHeight: Theme.minTarget)
            .contentShape(.rect)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var projectTitle: String {
        thread.projectTitle ?? thread.projectId ?? String(localized: "Other Threads", bundle: .module)
    }

    private var statusLabel: LocalizedStringResource? {
        switch thread.status {
        case "running", "preparing", "starting": LocalizedStringResource("Running", bundle: .atURL(Bundle.module.bundleURL))
        case "waiting", "queued": LocalizedStringResource("Waiting", bundle: .atURL(Bundle.module.bundleURL))
        case "failed": LocalizedStringResource("Failed", bundle: .atURL(Bundle.module.bundleURL))
        default: nil
        }
    }

    private func pick() {
        onPick(thread)
    }
}
