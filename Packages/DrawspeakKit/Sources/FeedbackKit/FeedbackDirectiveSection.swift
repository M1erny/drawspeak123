import SwiftUI
import DrawspeakCore

/// What the agent should do with the comments: continue proposals, make new ones, or reply.
struct FeedbackDirectiveSection: View {
    @Bindable var model: FeedbackPreviewModel

    var body: some View {
        Section {
            Picker(selection: $model.directiveMode) {
                Text("Continue", bundle: .module).tag(AgentDirective.Mode.continueProposals)
                Text("New Variants", bundle: .module).tag(AgentDirective.Mode.newVariants)
                Text("Reply Only", bundle: .module).tag(AgentDirective.Mode.replyOnly)
            } label: { Text("Agent Should", bundle: .module) }
            .pickerStyle(.segmented)
            if model.directiveMode == .newVariants {
                Picker(selection: $model.variantCount) {
                    ForEach(Array(AgentDirective.variantRange), id: \.self) { Text("\($0)").tag($0) }
                } label: { Text("Number of Variants", bundle: .module) }
                .pickerStyle(.segmented)
            }
            TextField(text: $model.directiveNote, axis: .vertical) {
                Text("Extra instruction (optional)", bundle: .module)
            }
            .lineLimit(1...4)
        } header: {
            Text("Agent", bundle: .module)
        } footer: {
            Text(footer, bundle: .module)
        }
        .disabled(model.busy)
    }

    private var footer: LocalizedStringKey {
        switch model.directiveMode {
        case .continueProposals:
            model.startsNewThread
                ? "Adds the next version to the proposals you commented on. A new thread starts without the agent's earlier work, so it can't continue it."
                : model.hasProposalComments
                    ? "Adds the next version to the proposals you commented on."
                    : "Comments on Now become one new proposal."
        case .newVariants: "Builds new proposals next to the existing ones and leaves them unchanged."
        case .replyOnly: "The agent answers in text. No mockups, no file changes."
        }
    }
}
