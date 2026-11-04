import SwiftUI
import DrawspeakCore

/// Where the feedback goes: the T3 Code thread, with its project, and a menu to change it.
struct FeedbackRecipientRow: View {
    let model: FeedbackPreviewModel
    let onChooseThread: (() -> Void)?

    var body: some View {
        Menu {
            Button(action: chooseThread) {
                Label { Text("Change Thread…", bundle: .module) } icon: { Image(systemName: "arrow.triangle.swap") }
            }
            .disabled(onChooseThread == nil)
            Button(action: model.chooseNewThread) {
                Label { Text("New Thread", bundle: .module) } icon: { Image(systemName: "plus.bubble") }
            }
            .disabled(!model.canStartNewThread)
        } label: {
            HStack(spacing: FeedbackLayout.spacing) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: FeedbackLayout.recipientSymbolSize))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.action)
                    .frame(width: FeedbackLayout.recipientSymbolSize + 12)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("To", bundle: .module).font(.caption).foregroundStyle(.secondary)
                    Group {
                        if model.startsNewThread { Text("New Thread", bundle: .module) }
                        else if let thread = model.recipient { Text(thread.threadTitle) }
                        else { Text("Choose Thread…", bundle: .module) }
                    }
                    .font(.headline)
                    .foregroundStyle(.primary)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.footnote).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .disabled(model.busy)
        .accessibilityLabel(Text("To", bundle: .module))
        .accessibilityValue(accessibilityValue)
    }

    private var subtitle: String {
        if model.startsNewThread { return String(localized: "Starts a thread in T3 Code", bundle: .module) }
        guard let thread = model.recipient else { return String(localized: "T3 Code", bundle: .module) }
        if let project = thread.projectTitle, !project.isEmpty { return String(localized: "\(project) · T3 Code", bundle: .module) }
        return String(localized: "T3 Code", bundle: .module)
    }

    private var accessibilityValue: String {
        if model.startsNewThread { return String(localized: "New Thread", bundle: .module) }
        return model.recipient?.displayName ?? String(localized: "No thread", bundle: .module)
    }

    private func chooseThread() {
        model.startsNewThread = false
        onChooseThread?()
    }
}
