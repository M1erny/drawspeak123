import DrawspeakCore
import SwiftUI

struct ScreenTargetSection: View {
    let canvas: ReviewCanvas?
    let screen: Screen
    let onChoose: (Workspace.ImportTarget) -> Void

    var body: some View {
        let proposals = canvas.map { CanvasLayout.proposalIds(in: $0, screen: screen) } ?? []
        Section(screen.title) {
            Button("New Now Version", systemImage: "arrow.triangle.2.circlepath") {
                onChoose(.baseline(screenId: screen.id))
            }
            ForEach(proposals, id: \.self) { proposalId in
                Button("Next Iteration of \(CanvasLayout.proposalTitle(proposalId))", systemImage: "square.stack") {
                    onChoose(.proposal(screenId: screen.id, proposalId: proposalId))
                }
            }
            Button("New \(CanvasLayout.proposalTitle(nextProposalId(after: proposals)))", systemImage: "plus.square.on.square") {
                onChoose(.proposal(screenId: screen.id, proposalId: nextProposalId(after: proposals)))
            }
        }
    }

    private func nextProposalId(after existing: [String]) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz".map(String.init)
        return letters.first { !existing.contains($0) } ?? "p\(existing.count + 1)"
    }
}
