#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// The screen row's title and drag handle. Dragging moves the whole row;
/// the move is saved when the drag ends.
struct ScreenTitleChip: View {
    let screen: Screen
    /// The persisted origin; `screen.origin` may include the live drag.
    let baseOrigin: WorldPoint
    let zoom: Double
    let workspace: Workspace
    let dragState: ScreenDragState

    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var draftTitle = ""

    /// Row step for the VoiceOver adjustable action, in world points.
    static let accessibilityStep = 120.0

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .opacity(isHovering || dragState.drag?.screenId == screen.id ? 1 : 0)
                .accessibilityHidden(true)
            Text(screen.title)
        }
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(minHeight: Theme.minTarget)
            .onHover { isHovering = $0 }
            .contentShape(.capsule)
            .hoverEffect(.highlight)
            .gesture(drag)
            .contextMenu {
                Button("Rename Screen…", systemImage: "pencil", action: beginRename)
            }
            .alert("Rename Screen", isPresented: $isRenaming) {
                TextField("Title", text: $draftTitle)
                Button("Rename", action: rename)
                Button("Cancel", role: .cancel) {}
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Screen \(screen.title)")
            .accessibilityHint("Drag to move this row. Swipe up or down to move it.")
            .accessibilityAdjustableAction(moveRow)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                dragState.drag = ScreenDrag(
                    screenId: screen.id,
                    dx: value.translation.width / zoom,
                    dy: value.translation.height / zoom
                )
            }
            .onEnded { value in
                move(dx: value.translation.width / zoom, dy: value.translation.height / zoom)
                dragState.drag = nil
            }
    }

    private func move(dx: Double, dy: Double) {
        workspace.moveScreen(screen.id, to: WorldPoint(x: baseOrigin.x + dx, y: baseOrigin.y + dy))
    }

    private func moveRow(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment: move(dx: 0, dy: Self.accessibilityStep)
        case .decrement: move(dx: 0, dy: -Self.accessibilityStep)
        @unknown default: break
        }
    }

    private func beginRename() {
        draftTitle = screen.title
        isRenaming = true
    }

    private func rename() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        workspace.renameScreen(screen.id, title: title)
    }
}
#endif
