import DrawspeakCore
import SwiftUI

struct ScreenTargetSection: View {
    let model: ScreenTargetModel
    @Binding var choice: ImportChoice

    var body: some View {
        Section(model.screen.title) {
            row(Text("Update Now"), .baseline(screenId: model.screen.id))
            ForEach(model.proposalIds, id: \.self) { proposalId in
                row(Text("Add to \(CanvasLayout.proposalTitle(proposalId))", comment: "Placeholder is a proposal name, e.g. Proposal A."),
                    .proposal(screenId: model.screen.id, proposalId: proposalId))
            }
            row(Text("New \(CanvasLayout.proposalTitle(model.nextProposalId))", comment: "Placeholder is a proposal name, e.g. Proposal B."),
                .proposal(screenId: model.screen.id, proposalId: model.nextProposalId))
        }
    }

    private func row(_ title: Text, _ target: Workspace.ImportTarget) -> ImportTargetRow {
        ImportTargetRow(title: title, isSelected: choice == .existing(target)) { choice = .existing(target) }
    }
}
