import SwiftUI
import DrawspeakCore

/// Progress and outcome of a send: what went where, message by message.
struct FeedbackDeliveryResult: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let model: FeedbackPreviewModel

    var body: some View {
        List {
            Section {
                VStack(spacing: FeedbackLayout.spacing) {
                    Image(systemName: phase.symbol)
                        .font(.system(size: FeedbackLayout.resultSymbolSize))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(phase.tint)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: model.allSent)
                        .symbolEffectsRemoved(reduceMotion)
                        .accessibilityHidden(true)
                    Text(phase.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(detail)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if phase == .working {
                        ProgressView(value: progress).padding(.top, FeedbackLayout.rowPadding)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, FeedbackLayout.sectionSpacing)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
            }

            if let recipient = model.recipient {
                Section {
                    LabeledContent { Text(recipient.threadTitle) } label: { Text("Thread", bundle: .module) }
                    if let project = recipient.projectTitle, !project.isEmpty {
                        LabeledContent { Text(project) } label: { Text("Project", bundle: .module) }
                    }
                    if let date = model.entries.compactMap(\.receipt?.acknowledgedAt).max() {
                        LabeledContent { Text(date, format: .dateTime.hour().minute()) } label: { Text("Delivered", bundle: .module) }
                    }
                } header: { Text("Sent To", bundle: .module) }
            }

            if model.series.count > 1 {
                Section {
                    ForEach(Array(model.series.enumerated()), id: \.element.batchId) { offset, part in
                        FeedbackPartRow(index: offset + 1, count: model.series.count, part: part,
                                        entry: model.entries.first { $0.id == part.batchId })
                    }
                } header: { Text("Messages", bundle: .module) }
            }

            if phase.offersAction {
                Section {
                    FeedbackResultActions(model: model, phase: phase)
                } footer: {
                    if let notice = model.reconciliationNotice ?? model.error { Text(notice) }
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: phase)
    }

    private var phase: FeedbackResultPhase { model.resultPhase }

    private var commentCount: Int { model.series.reduce(0) { $0 + $1.items.count } }
    private var screenCount: Int { model.series.reduce(0) { $0 + $1.groups.count } }

    private var detail: String {
        let comments = commentCount, screens = screenCount, total = model.series.count, sent = model.sentCount
        switch phase {
        case .sent where total > 1:
            return String(AttributedString(localized: "^[\(comments) comment](inflect: true) on ^[\(screens) screen](inflect: true) in \(total) messages. The agent works on them in the thread.", bundle: .module).characters)
        case .sent:
            return String(AttributedString(localized: "^[\(comments) comment](inflect: true) on ^[\(screens) screen](inflect: true). The agent works on them in the thread.", bundle: .module).characters)
        case .working where total > 1:
            return String(localized: "Message \(min(sent + 1, total)) of \(total). Keep Drawspeak open until it finishes.", bundle: .module)
        case .working:
            return String(localized: "Uploading screenshots. Keep Drawspeak open until it finishes.", bundle: .module)
        case .unknown:
            return String(localized: "The connection dropped while sending. Check the thread before sending again, so nothing arrives twice.", bundle: .module)
        case .ready:
            return String(localized: "This message was not found in the thread. Sending it again may duplicate it.", bundle: .module)
        case .failed:
            if case .failed(let reason) = model.entry?.state, sent == 0 { return reason }
            if case .failed(let reason) = model.entry?.state {
                return String(localized: "\(sent) of \(total) messages sent. \(reason)", bundle: .module)
            }
            return model.error ?? String(localized: "Nothing was sent.", bundle: .module)
        }
    }

    private var progress: Double {
        let total = Double(max(model.series.count, 1))
        var done = Double(model.sentCount)
        if case .uploading(let uploaded, let files) = model.entry?.state, files > 0 { done += Double(uploaded) / Double(files) * 0.9 }
        if case .sending = model.entry?.state { done += 0.9 }
        return min(done / total, 1)
    }

}
