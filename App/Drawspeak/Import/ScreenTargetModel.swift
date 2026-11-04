import DrawspeakCore
import Foundation

/// The import targets of one screen, prepared when the canvas changes.
struct ScreenTargetModel: Identifiable, Equatable {
    var screen: Screen
    var proposalIds: [String]
    var nextProposalId: String

    var id: String { screen.id }

    static func make(_ canvas: ReviewCanvas?) -> [ScreenTargetModel] {
        guard let canvas else { return [] }
        return canvas.screens.map { screen in
            let proposals = CanvasLayout.proposalIds(in: canvas, screen: screen)
            return ScreenTargetModel(screen: screen, proposalIds: proposals, nextProposalId: nextProposalId(after: proposals))
        }
    }

    private static func nextProposalId(after existing: [String]) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz".map(String.init)
        return letters.first { !existing.contains($0) } ?? "p\(existing.count + 1)"
    }
}
