import SwiftUI
import DrawspeakCore

struct ThreadPickerRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let thread: ThreadSummary
    let isSelected: Bool
    let onPick: (ThreadSummary) -> Void

    var body: some View {
        Button(action: pick) {
            HStack {
                VStack(alignment: .leading) {
                    Text(verbatim: thread.title)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    if let updatedAt = thread.updatedAt {
                        Text("\(projectTitle) · \(Text(updatedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated)))", bundle: .module)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    } else {
                        Text(verbatim: projectTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    }
                }
                Spacer()
                if let symbol = statusSymbol {
                    Image(systemName: symbol)
                        .symbolEffect(.rotate, options: .repeating, isActive: isRunning && !reduceMotion)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text(statusLabel))
                }
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

    private var isRunning: Bool {
        ["running", "preparing", "starting", "queued"].contains(thread.status ?? "")
    }

    private var statusSymbol: String? {
        if isRunning { return "progress.indicator" }
        switch thread.status {
        case "waiting": return "exclamationmark.bubble"
        case "failed": return "xmark.circle"
        default: return nil
        }
    }

    private var statusLabel: String {
        if isRunning { return String(localized: "Running", bundle: .module) }
        return thread.status == "waiting"
            ? String(localized: "Needs Input", bundle: .module)
            : String(localized: "Failed", bundle: .module)
    }

    private func pick() {
        onPick(thread)
    }
}
