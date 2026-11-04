import CoreGraphics
import DrawspeakCore
import Foundation
import HTMLKit

/// Routes canvas input: camera gestures, drawing, Pencil pressure selection,
/// the component chooser and hover previews. Overlays observe its small
/// models; the workspace is written only when a mark is committed or a camera
/// gesture ends.
final class CanvasInteraction {
    weak var workspace: Workspace?
    let camera = CanvasCamera()
    let draft = InkDraft()
    let pick = ComponentPick()
    let status = CanvasStatus()
    let inspectors = InspectorRegistry()

    var tool: CanvasTool = .hand {
        didSet {
            guard tool != oldValue else { return }
            cancelMarking()
            endHover()
            if tool != .component { dismissChooser() }
            onSettingsChange?()
        }
    }

    var interactingSnapshotId: String?

    /// The input surface leaves this card to its isolated web view.
    func isInteracting(at screen: CGPoint) -> Bool {
        guard let id = interactingSnapshotId, let canvas = workspace?.currentCanvas else { return false }
        let world = CanvasFraming.screenToWorld(screen, camera: camera.state)
        return CanvasWorldLayout(canvas: canvas).slot(at: world)?.snapshot?.id == id
    }

    var drawWithFinger = false {
        didSet {
            guard drawWithFinger != oldValue else { return }
            cancelMarking()
            onSettingsChange?()
        }
    }

    /// Lets the input surface reconfigure its recognizers when the tool or
    /// Draw with Finger changes.
    var onSettingsChange: (() -> Void)?

    /// The last Pencil or pointer hover location, for placing the squeeze palette.
    private(set) var lastHoverLocation: CGPoint?

    /// Moving the Pencil tip this far (screen points) cancels a pressure selection.
    static let pressureCancelDistance: CGFloat = 24

    private var pressure: PressureSession?
    private var draftCanvasId: UUID?
    private var chooserCanvasId: UUID?
    private var isCameraGestureActive = false
    private var isHovering = false
    private var hoverProbeInFlight = false
    private var pendingHover: CGPoint?

    /// One finger draws instead of panning; two fingers still pan and zoom.
    var fingerDraws: Bool { drawWithFinger && tool != .hand }

    func acceptsMarking(from kind: InputKind) -> Bool {
        guard tool != .hand else { return false }
        switch kind {
        case .pencil, .pointer: return true
        case .finger: return drawWithFinger
        }
    }

    // MARK: - Camera

    func loadCamera(_ state: CameraState) {
        cancelMarking()
        dismissChooser()
        endHover()
        camera.apply(state)
        camera.settle()
    }

    /// Adopts a camera set elsewhere (Fit All, zoom buttons, framing a note).
    /// Returns false when it is already shown or a gesture is in progress.
    @discardableResult
    func adoptCamera(_ state: CameraState) -> Bool {
        guard !isCameraGestureActive, state != camera.state else { return false }
        camera.apply(state)
        camera.settle()
        return true
    }

    func cameraGestureBegan() {
        isCameraGestureActive = true
        // A pinch or pan while pressing with the component tool cancels the selection.
        if pressure != nil {
            pressure = nil
            pick.clear()
        }
    }

    func pan(by translation: CGPoint) {
        guard translation != .zero else { return }
        camera.offset = CGPoint(x: camera.offset.x + translation.x, y: camera.offset.y + translation.y)
    }

    func zoom(by factor: Double, around point: CGPoint) {
        camera.apply(CanvasFraming.zoomed(camera.state, by: factor, around: point))
    }

    /// Persists the camera once, when the last camera gesture ends.
    func cameraGestureEnded() {
        isCameraGestureActive = false
        camera.settle()
        guard let workspace, let canvasId = workspace.currentCanvasId,
              workspace.currentCanvas?.camera != camera.state else { return }
        workspace.updateCamera(camera.state, canvasId: canvasId)
    }

    // MARK: - Marks

    /// Starts a mark or a pressure selection. Returns false when the touch
    /// does not start on an available snapshot card.
    func markBegan(at screen: CGPoint, kind: InputKind, force: Double?, time: TimeInterval) -> Bool {
        guard !isInteracting(at: screen), acceptsMarking(from: kind), let workspace, let canvas = workspace.currentCanvas else { return false }
        let world = CanvasFraming.screenToWorld(screen, camera: camera.state)
        guard let slot = CanvasWorldLayout(canvas: canvas).slot(at: world), let snapshot = slot.snapshot,
              workspace.isSourceAvailable(snapshot) else { return false }
        dismissChooser()
        endHover()
        if tool == .component, snapshot.kind == .html {
            guard kind == .pencil else { return false }
            beginPressure(slot: slot, snapshot: snapshot, canvasId: canvas.id, world: world, screen: screen, force: force, time: time)
            return true
        }
        guard let markKind = tool.markKind else { return false }
        draft.begin(kind: markKind, snapshotId: snapshot.id, frame: slot.frame, at: world)
        draftCanvasId = canvas.id
        return true
    }

    func markMoved(to screen: CGPoint, force: Double?, time: TimeInterval) {
        if pressure != nil {
            pressureMoved(to: screen, force: force, time: time)
            return
        }
        guard draft.isActive else { return }
        let world = CanvasFraming.screenToWorld(screen, camera: camera.state)
        draft.append(world, minimumDistance: 1 / CGFloat(camera.zoom))
    }

    func markEnded(at screen: CGPoint) {
        if pressure != nil {
            pressureEnded()
            return
        }
        guard draft.isActive, let kind = draft.kind, let snapshotId = draft.snapshotId else { return }
        draft.append(CanvasFraming.screenToWorld(screen, camera: camera.state), minimumDistance: .ulpOfOne)
        let points = draft.points
        let frame = draft.frame
        let canvasId = draftCanvasId
        draft.clear()
        draftCanvasId = nil
        guard let workspace, workspace.currentCanvasId == canvasId else { return }
        guard let shape = StrokeClassifier.shape(for: points, kind: kind, zoom: camera.zoom, in: frame) else {
            let travel = StrokeClassifier.pathLength(points) * CGFloat(camera.zoom)
            if kind == .region, travel >= StrokeClassifier.minimumMarkSize {
                status.show(String(localized: "Draw a larger area", bundle: .module))
            }
            return
        }
        workspace.addNote(snapshotId: snapshotId, shape: shape)
    }

    func markCancelled() {
        cancelMarking()
    }

    func cancelMarking() {
        draft.clear()
        draftCanvasId = nil
        if pressure != nil {
            pressure = nil
            pick.clear()
        }
    }

    // MARK: - Pencil pressure

    private func beginPressure(slot: LaneSlot, snapshot: Snapshot, canvasId: UUID, world: CGPoint, screen: CGPoint, force: Double?, time: TimeInterval) {
        let inspector = inspectors.inspector(slotId: slot.id, snapshotId: snapshot.id)
        guard inspector.isReady else {
            status.show(String(localized: "Still loading", bundle: .module))
            return
        }
        var session = PressureSession(canvasId: canvasId, slotId: slot.id, snapshotId: snapshot.id, frame: slot.frame, start: screen, inspector: inspector)
        if let force { session.lastSample = (force, time) }
        pressure = session
        pick.selection = nil
        pick.tipLocation = screen
        let token = session.token
        let point = SnapshotSpace.normalized(world, in: slot.frame)
        let inspectors = inspectors
        Task { _ = try? await inspectors.renderHash(snapshotId: snapshot.id, inspector: inspector) }
        Task {
            let result = try? await inspector.probe(at: point)
            self.pressureProbeFinished(token: token, result: result)
        }
    }

    private func pressureProbeFinished(token: UUID, result: DOMProbeResult?) {
        guard var session = pressure, session.token == token else { return }
        var selection = ComponentSelection(
            slotId: session.slotId, snapshotId: session.snapshotId, frame: session.frame,
            layers: result?.layers ?? [], method: .pencilPressure
        )
        guard !selection.isEmpty else {
            pressure = nil
            pick.clear()
            status.show(result == nil ? String(localized: "Can't read this HTML", bundle: .module) : String(localized: "No component here", bundle: .module))
            return
        }
        var tracker = PressureDepthTracker(levels: selection.chain.count)
        if let sample = session.lastSample {
            tracker.update(force: sample.force, at: sample.time)
            session.stableForce = sample.force
        }
        selection.select(depth: tracker.depth)
        session.tracker = tracker
        session.selection = selection
        pressure = session
        pick.selection = selection
        if session.liftPending { finishPressure() }
    }

    private func pressureMoved(to screen: CGPoint, force: Double?, time: TimeInterval) {
        guard var session = pressure else { return }
        if StrokeClassifier.distance(screen, session.start) > Self.pressureCancelDistance {
            pressure = nil
            pick.clear()
            return
        }
        pick.tipLocation = screen
        guard let force else { return }
        session.lastSample = (force, time)
        if var tracker = session.tracker {
            let depth = tracker.update(force: force, at: time)
            if depth == tracker.stableDepth { session.stableForce = force }
            session.tracker = tracker
            session.selection?.select(depth: depth)
            if pick.selection != session.selection { pick.selection = session.selection }
        }
        pressure = session
    }

    private func pressureEnded() {
        guard var session = pressure else { return }
        guard session.tracker != nil else {
            session.liftPending = true
            pressure = session
            return
        }
        finishPressure()
    }

    /// Lift commits the last stable depth; later force estimates are ignored.
    private func finishPressure() {
        guard let session = pressure else { return }
        pressure = nil
        pick.clear()
        guard let tracker = session.tracker, var selection = session.selection else { return }
        selection.select(depth: tracker.commit())
        selection.pressure = session.stableForce
        commit(selection, inspector: session.inspector, canvasId: session.canvasId)
    }

    // MARK: - Chooser (touch, pointer, keyboard, VoiceOver)

    /// A finger or pointer tap with the component tool opens the chooser.
    func tap(at screen: CGPoint, kind: InputKind) {
        guard !isInteracting(at: screen), tool == .component, let workspace, let canvas = workspace.currentCanvas else { return }
        let world = CanvasFraming.screenToWorld(screen, camera: camera.state)
        guard let slot = CanvasWorldLayout(canvas: canvas).slot(at: world), let snapshot = slot.snapshot,
              workspace.isSourceAvailable(snapshot) else {
            dismissChooser()
            return
        }
        guard snapshot.kind == .html else {
            status.show(String(localized: "Images have no components", bundle: .module))
            return
        }
        openChooser(
            slot: slot, snapshot: snapshot, canvasId: canvas.id,
            point: SnapshotSpace.normalized(world, in: slot.frame), anchor: screen,
            method: kind == .pointer ? .pointer : .touch
        )
    }

    /// Opens the chooser at the center of an HTML card, without a gesture.
    func openChooser(slotId: String, method: SelectionMethod) {
        guard let workspace, let canvas = workspace.currentCanvas,
              let slot = CanvasWorldLayout(canvas: canvas).slot(id: slotId), let snapshot = slot.snapshot,
              snapshot.id != interactingSnapshotId, snapshot.kind == .html, workspace.isSourceAvailable(snapshot) else { return }
        let center = CanvasFraming.worldToScreen(CGPoint(x: slot.frame.midX, y: slot.frame.midY), camera: camera.state)
        openChooser(slot: slot, snapshot: snapshot, canvasId: canvas.id, point: NPoint(x: 0.5, y: 0.5), anchor: center, method: method)
    }

    private func openChooser(slot: LaneSlot, snapshot: Snapshot, canvasId: UUID, point: NPoint, anchor: CGPoint, method: SelectionMethod) {
        let inspector = inspectors.inspector(slotId: slot.id, snapshotId: snapshot.id)
        chooserCanvasId = canvasId
        Task {
            // A card switched to live HTML a moment ago may still be loading.
            for _ in 0..<30 where !inspector.isReady {
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard inspector.isReady else {
                status.show(String(localized: "Still loading", bundle: .module))
                return
            }
            let result = try? await inspector.probe(at: point)
            let selection = ComponentSelection(slotId: slot.id, snapshotId: snapshot.id, frame: slot.frame, layers: result?.layers ?? [], method: method)
            guard workspace?.currentCanvasId == canvasId, chooserCanvasId == canvasId else { return }
            guard !selection.isEmpty else {
                status.show(result == nil ? String(localized: "Can't read this HTML", bundle: .module) : String(localized: "No component here", bundle: .module))
                return
            }
            pick.showChooser(selection, at: anchor)
        }
    }

    /// "Comment on <label>": confirms the chooser's selection.
    func commitChooser() {
        guard pick.isChooserPresented, let selection = pick.selection, let canvasId = chooserCanvasId,
              let inspector = inspectors.existingInspector(slotId: selection.slotId, snapshotId: selection.snapshotId) else {
            dismissChooser()
            return
        }
        chooserCanvasId = nil
        pick.clear()
        commit(selection, inspector: inspector, canvasId: canvasId)
    }

    func dismissChooser() {
        chooserCanvasId = nil
        guard pressure == nil else { return }
        pick.clear()
    }

    private func commit(_ selection: ComponentSelection, inspector: DOMInspector, canvasId: UUID) {
        let inspectors = inspectors
        Task {
            let renderHash: String
            do {
                renderHash = try await inspectors.renderHash(snapshotId: selection.snapshotId, inspector: inspector)
            } catch {
                status.show(String(localized: "Can't read this HTML", bundle: .module))
                return
            }
            guard let workspace, workspace.currentCanvasId == canvasId,
                  let snapshot = workspace.currentCanvas?.snapshots.first(where: { $0.id == selection.snapshotId }),
                  let target = ComponentTargetBuilder.target(for: selection, snapshot: snapshot, renderHash: renderHash) else { return }
            workspace.addNote(snapshotId: snapshot.id, shape: .component(target.bounds), domTarget: target)
        }
    }

    // MARK: - Hover

    /// Pencil hover or pointer movement. With the component tool it previews
    /// the element under the tip; it never creates a comment.
    func hover(at screen: CGPoint?) {
        guard let screen else {
            endHover()
            return
        }
        lastHoverLocation = screen
        isHovering = true
        guard tool == .component, pressure == nil, !pick.isChooserPresented else { return }
        guard !hoverProbeInFlight else {
            pendingHover = screen
            return
        }
        probeHover(at: screen)
    }

    private func endHover() {
        isHovering = false
        pendingHover = nil
        if pick.hover != nil { pick.hover = nil }
    }

    private func probeHover(at screen: CGPoint) {
        guard let canvas = workspace?.currentCanvas else { return }
        let world = CanvasFraming.screenToWorld(screen, camera: camera.state)
        guard let slot = CanvasWorldLayout(canvas: canvas).slot(at: world), let snapshot = slot.snapshot, snapshot.kind == .html,
              let inspector = inspectors.existingInspector(slotId: slot.id, snapshotId: snapshot.id), inspector.isReady else {
            if pick.hover != nil { pick.hover = nil }
            return
        }
        hoverProbeInFlight = true
        let point = SnapshotSpace.normalized(world, in: slot.frame)
        Task {
            let result = try? await inspector.probe(at: point)
            hoverProbeInFlight = false
            let showsPreview = isHovering && tool == .component && pressure == nil && !pick.isChooserPresented
            if showsPreview, let element = result?.layers.first?.first {
                let outline = HoverOutline(slotId: slot.id, frame: slot.frame, element: element)
                if pick.hover != outline { pick.hover = outline }
            } else if pick.hover != nil {
                pick.hover = nil
            }
            if let next = pendingHover {
                pendingHover = nil
                if isHovering { probeHover(at: next) }
            }
        }
    }

    // MARK: - Accessibility

    /// Focuses the first comment on a snapshot.
    func showComments(onSnapshot snapshotId: String) {
        guard let workspace,
              let note = workspace.currentCanvas?.notes.filter({ $0.snapshotId == snapshotId }).min(by: { $0.ordinal < $1.ordinal }) else { return }
        workspace.focusedNoteId = note.id
    }
}
