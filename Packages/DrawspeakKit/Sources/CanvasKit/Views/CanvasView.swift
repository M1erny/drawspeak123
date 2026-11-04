#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// The full-screen review canvas of the workspace's current canvas: screens
/// with Now and proposal lanes side by side, notes' marks and pins, drawing
/// with Apple Pencil (or a finger when enabled) and HTML component selection.
///
/// Fingers pan and pinch; Pencil never pans. The camera is saved with
/// `Workspace.updateCamera` when a gesture ends. Setting a canvas camera in
/// the workspace from outside (Fit All, zoom buttons, framing a note) moves
/// the view there, animated unless Reduce Motion is on.
public struct CanvasView: View {
    private let workspace: Workspace
    @Binding private var tool: CanvasTool
    private let drawWithFinger: Bool
    private let overlayInsets: EdgeInsets
    @Binding private var squeezeAnchor: CGPoint?
    private let onSqueeze: (() -> Void)?
    private let onAddRegion: ((String) -> Void)?

    @State private var interactingSnapshotId: String?
    @State private var interaction = CanvasInteraction()
    @State private var dragState = ScreenDragState()
    @State private var previousTool: CanvasTool?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.preferredPencilDoubleTapAction) private var doubleTapAction
    @Environment(\.preferredPencilSqueezeAction) private var squeezeAction

    /// - Parameters:
    ///   - overlayInsets: Space covered by the app's floating palettes; the
    ///     canvas keeps its own hints clear of it.
    ///   - squeezeAnchor: Set to the Pencil hover location (in this view's
    ///     coordinates) right before `onSqueeze` runs, for placing the palette.
    ///   - onSqueeze: Apple Pencil Pro squeeze, or a double tap set to show a palette.
    ///   - onAddRegion: The "Add Region…" accessibility action of a card, with
    ///     its snapshot id; `nil` hides the action.
    public init(
        workspace: Workspace,
        tool: Binding<CanvasTool>,
        drawWithFinger: Bool,
        overlayInsets: EdgeInsets = .init(),
        squeezeAnchor: Binding<CGPoint?> = .constant(nil),
        onSqueeze: (() -> Void)? = nil,
        onAddRegion: ((String) -> Void)? = nil
    ) {
        self.workspace = workspace
        self._tool = tool
        self.drawWithFinger = drawWithFinger
        self.overlayInsets = overlayInsets
        self._squeezeAnchor = squeezeAnchor
        self.onSqueeze = onSqueeze
        self.onAddRegion = onAddRegion
    }

    public var body: some View {
        let canvas = workspace.currentCanvas
        let layout = canvas.map { CanvasWorldLayout(canvas: $0, drag: dragState.drag) }
        let notes = canvas?.notes ?? []
        let marks = layout.map { PlacedMark.marks(in: $0, notes: notes) } ?? []
        let commentCounts = Dictionary(grouping: notes, by: \.snapshotId).mapValues(\.count)
        @Bindable var pick = interaction.pick

        ZStack(alignment: .topLeading) {
            Theme.canvas
            CameraTransform(camera: interaction.camera) {
                ZStack(alignment: .topLeading) {
                    CardsLayer(
                        slots: layout?.slots ?? [],
                        commentCounts: commentCounts,
                        tool: tool,
                        workspace: workspace,
                        interaction: interaction,
                        actions: cardActions,
                        interactingSnapshotId: interactingSnapshotId
                    )
                    MarksLayer(marks: marks, focusedNoteId: workspace.focusedNoteId, camera: interaction.camera)
                    ComponentOutlineLayer(pick: interaction.pick, camera: interaction.camera)
                    DraftLayer(draft: interaction.draft, camera: interaction.camera)
                }
            }
            CanvasInputLayer(interaction: interaction)
            ScreenOverlay(
                rows: layout?.rows ?? [],
                marks: marks,
                focusedNoteId: workspace.focusedNoteId,
                recordingNoteId: workspace.activeRecording?.noteId,
                workspace: workspace,
                interaction: interaction,
                dragState: dragState,
                interactingSnapshotId: $interactingSnapshotId
            )
            ComponentChip(pick: interaction.pick)
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            VStack {
                if interactingSnapshotId != nil {
                    HStack {
                        Text("Interacting — tap Done to annotate")
                        Button("Done") { interactingSnapshotId = nil }
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .background(Theme.surface, in: .capsule)
                    .accessibilityHint("Prototype state changes are not saved. Done returns to the original snapshot.")
                }
                StatusBanner(status: interaction.status)
            }
                .padding(.top, overlayInsets.top + 12)
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            interaction.camera.viewSize = size
        }
        .popover(
            isPresented: $pick.isChooserPresented,
            attachmentAnchor: .rect(.rect(CGRect(origin: pick.chooserAnchor, size: CGSize(width: 1, height: 1))))
        ) {
            ComponentChooser(pick: interaction.pick, onCommit: interaction.commitChooser, onCancel: interaction.dismissChooser)
                .presentationCompactAdaptation(.popover)
        }
        .onChange(of: pick.isChooserPresented) { _, isPresented in
            if !isPresented { interaction.dismissChooser() }
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

    private var cardActions: CardActions {
        CardActions(
            addRegion: onAddRegion,
            selectComponent: selectComponent,
            showComments: interaction.showComments(onSnapshot:)
        )
    }

    private func selectComponent(slotId: String) {
        tool = .component
        interaction.openChooser(slotId: slotId, method: .keyboard)
    }

    /// Moves to a camera set outside the canvas; jumps under Reduce Motion.
    private func adopt(_ camera: CameraState?) {
        guard let camera else { return }
        if reduceMotion {
            interaction.adoptCamera(camera)
        } else {
            withAnimation(.smooth(duration: 0.3)) {
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
