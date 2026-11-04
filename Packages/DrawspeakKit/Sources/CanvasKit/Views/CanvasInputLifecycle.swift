#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Input preferences and camera lifecycle, separate from canvas rendering.
struct CanvasInputLifecycle: ViewModifier {
    let workspace: Workspace
    let interaction: CanvasInteraction
    let drawWithFinger: Bool
    let onSqueeze: (() -> Void)?
    @Binding var tool: CanvasTool
    @Binding var interactingSnapshotId: String?
    @Binding var squeezeAnchor: CGPoint?
    @State private var previousTool: CanvasTool?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.preferredPencilDoubleTapAction) private var doubleTapAction
    @Environment(\.preferredPencilSqueezeAction) private var squeezeAction
    func body(content: Content) -> some View {
        let canvas = workspace.currentCanvas
        content
        .sensoryFeedback(.selection, trigger: tool) { _, _ in !reduceMotion }
        .sensoryFeedback(.impact, trigger: interaction.commitFeedback.noteId) { _, noteId in
            !reduceMotion && noteId != nil
        }
        .onPencilSqueeze(perform: handleSqueeze)
        .onPencilDoubleTap(perform: handleDoubleTap)
        .onChange(of: tool, initial: true) { oldTool, newTool in
            interaction.tool = newTool
            if oldTool != newTool { previousTool = oldTool }
        }
        .onChange(of: drawWithFinger, initial: true) {
            interaction.drawWithFinger = drawWithFinger
        }
        .onChange(of: workspace.currentCanvasId, initial: true) {
            interactingSnapshotId = nil
            interaction.workspace = workspace
            interaction.loadCamera(workspace.currentCanvas?.camera ?? CameraState())
        }
        .onChange(of: interactingSnapshotId) {
            interaction.interactingSnapshotId = interactingSnapshotId
            interaction.cancelMarking()
            interaction.dismissChooser()
        }
        .onChange(of: canvas) {
            if let id = interactingSnapshotId,
               !((canvas.map { CanvasWorldLayout(canvas: $0).slots.contains { $0.snapshot?.id == id } }) ?? false) {
                interactingSnapshotId = nil
            }
        }
        .onChange(of: canvas?.camera) { _, camera in
            adopt(camera)
        }
    }

    /// Moves to a camera set outside the canvas; jumps under Reduce Motion.
    private func adopt(_ camera: CameraState?) {
        guard let camera else { return }
        if reduceMotion {
            interaction.adoptCamera(camera)
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                _ = interaction.adoptCamera(camera)
            }
        }
    }

    private func handleSqueeze(_ phase: PencilSqueezeGesturePhase) {
        guard case .ended(let value) = phase else { return }
        perform(squeezeAction, hoverLocation: value.hoverPose?.location)
    }

    private func handleDoubleTap(_ value: PencilDoubleTapGestureValue) {
        perform(doubleTapAction, hoverLocation: value.hoverPose?.location)
    }

    /// Applies the person's preferred Pencil action. There is no eraser, so
    /// the eraser action toggles the hand tool.
    private func perform(_ action: PencilPreferredAction, hoverLocation: CGPoint?) {
        switch action {
        case .switchPrevious:
            tool = alternateTool
        case .switchEraser:
            tool = tool == .hand ? alternateTool : .hand
        case .showContextualPalette, .showColorPalette, .showInkAttributes:
            squeezeAnchor = hoverLocation ?? interaction.lastHoverLocation
            onSqueeze?()
        default:
            break
        }
    }

    /// The previous tool, or a sensible partner when there is none yet.
    private var alternateTool: CanvasTool {
        if let previousTool, previousTool != tool { return previousTool }
        return tool == .hand ? .region : .hand
    }
}
#endif
