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
    @State private var presentation = CanvasPresentation()


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
        @Bindable var pick = interaction.pick

        CanvasContent(bubbleInsets: overlayInsets, workspace: workspace, tool: tool, interaction: interaction,
                      presentation: presentation, dragState: dragState, actions: cardActions,
                      interactingSnapshotId: $interactingSnapshotId)
        .background { Theme.canvas.ignoresSafeArea() }
        .safeAreaInset(edge: .top, spacing: 0) {
            StatusBanner(status: interaction.status).padding(.top, overlayInsets.top)
        }
        .onChange(of: canvas, initial: true) { presentation.update(canvas: canvas, drag: dragState.drag, visibleNotes: workspace.visibleNotes()) }
        .onChange(of: workspace.showsSentNotes) { presentation.update(canvas: canvas, drag: dragState.drag, visibleNotes: workspace.visibleNotes()) }
        .onChange(of: dragState.drag) { presentation.move(canvas: canvas, drag: dragState.drag) }
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
        .modifier(CanvasInputLifecycle(workspace: workspace, interaction: interaction,
                                       drawWithFinger: drawWithFinger, onSqueeze: onSqueeze,
                                       tool: $tool, interactingSnapshotId: $interactingSnapshotId,
                                       squeezeAnchor: $squeezeAnchor))
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

}
#endif
