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
        Text(screen.title)
            .overlay(alignment: .leading) {
                Image(systemName: "line.3.horizontal")
                    .offset(x: -Theme.minTarget / 2)
                    .opacity(isHovering || dragState.drag?.screenId == screen.id ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .frame(minHeight: Theme.minTarget)
            .onHover { isHovering = $0 }
            .contentShape(.capsule)
            .hoverEffect(.highlight)
            .gesture(drag)
            .contextMenu {
                Button(String(localized: "Rename Screen…", bundle: .module), systemImage: "pencil", action: beginRename)
            }
            .alert(String(localized: "Rename Screen", bundle: .module), isPresented: $isRenaming) {
                TextField(String(localized: "Title", bundle: .module), text: $draftTitle)
                Button(String(localized: "Rename", bundle: .module), action: rename)
                Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Screen \(screen.title)", bundle: .module, comment: "User-assigned screen title."))
            .accessibilityHint(Text("Drag to move this row. Swipe up or down to move it.", bundle: .module))
            .accessibilityAdjustableAction(moveRow)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged(changeDrag)
            .onEnded(endDrag)
    }
    private func changeDrag(_ value: DragGesture.Value) {
        dragState.drag = ScreenDrag(screenId: screen.id, dx: value.translation.width / zoom, dy: value.translation.height / zoom)
    }
    private func endDrag(_ value: DragGesture.Value) {
        move(dx: value.translation.width / zoom, dy: value.translation.height / zoom)
        dragState.drag = nil
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
