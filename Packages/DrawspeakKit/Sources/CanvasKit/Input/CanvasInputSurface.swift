#if canImport(UIKit)
import HTMLKit
import UIKit

/// The single UIKit input layer. UIKit is needed to tell Pencil from finger
/// (`UITouch.type`), to read Pencil force and to receive trackpad scrolls.
/// Fingers pan and pinch; Pencil and pointer drags mark; the hand tool and
/// Pencil never pan together.
final class CanvasInputSurface: UIView, UIGestureRecognizerDelegate {
    private let interaction: CanvasInteraction
    private let panRecognizer = UIPanGestureRecognizer()
    private let scrollRecognizer = UIPanGestureRecognizer()
    private let pinchRecognizer = UIPinchGestureRecognizer()
    private let tapRecognizer = UITapGestureRecognizer()
    private let hoverRecognizer = UIHoverGestureRecognizer()
    private var markingTouch: UITouch?
    private var lastTapKind: InputKind = .finger

    init(interaction: CanvasInteraction) {
        self.interaction = interaction
        super.init(frame: .zero)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        isAccessibilityElement = false

        panRecognizer.addTarget(self, action: #selector(handlePan(_:)))
        panRecognizer.maximumNumberOfTouches = 2
        panRecognizer.delaysTouchesEnded = false
        panRecognizer.delegate = self

        // Trackpad two-finger scroll and mouse wheel; no touches.
        scrollRecognizer.addTarget(self, action: #selector(handlePan(_:)))
        scrollRecognizer.allowedScrollTypesMask = .all
        scrollRecognizer.allowedTouchTypes = []
        scrollRecognizer.delegate = self

        pinchRecognizer.addTarget(self, action: #selector(handlePinch(_:)))
        pinchRecognizer.delegate = self

        tapRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        tapRecognizer.delaysTouchesEnded = false
        tapRecognizer.delegate = self

        hoverRecognizer.addTarget(self, action: #selector(handleHover(_:)))

        for recognizer in [panRecognizer, scrollRecognizer, pinchRecognizer, tapRecognizer, hoverRecognizer] {
            addGestureRecognizer(recognizer)
        }
        configure()
        interaction.onSettingsChange = { [weak self] in self?.configure() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Applies the current tool and Draw with Finger setting.
    func configure() {
        let minimum = interaction.fingerDraws ? 2 : 1
        if panRecognizer.minimumNumberOfTouches != minimum {
            panRecognizer.minimumNumberOfTouches = minimum
        }
    }

    // MARK: - Camera gestures

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            interaction.cameraGestureBegan()
            applyTranslation(of: recognizer)
        case .changed:
            applyTranslation(of: recognizer)
        case .ended, .cancelled, .failed:
            endCameraGestureIfIdle()
        default:
            break
        }
    }

    private func applyTranslation(of recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self)
        recognizer.setTranslation(.zero, in: self)
        interaction.pan(by: translation)
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            if recognizer.state == .began { interaction.cameraGestureBegan() }
            interaction.zoom(by: Double(recognizer.scale), around: recognizer.location(in: self))
            recognizer.scale = 1
        case .ended, .cancelled, .failed:
            endCameraGestureIfIdle()
        default:
            break
        }
    }

    private func endCameraGestureIfIdle() {
        let active = [panRecognizer, scrollRecognizer, pinchRecognizer].contains { $0.state == .began || $0.state == .changed }
        if !active { interaction.cameraGestureEnded() }
    }

    // MARK: - Taps and hover

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        interaction.tap(at: recognizer.location(in: self), kind: lastTapKind)
    }

    @objc private func handleHover(_ recognizer: UIHoverGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            interaction.hover(at: recognizer.location(in: self))
        default:
            interaction.hover(at: nil)
        }
    }

    // MARK: - Marking touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard markingTouch == nil else { return }
        for touch in touches {
            let kind = Self.kind(of: touch)
            guard interaction.acceptsMarking(from: kind) else { continue }
            if interaction.markBegan(at: touch.location(in: self), kind: kind, force: Self.force(of: touch), time: touch.timestamp) {
                markingTouch = touch
                return
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = markingTouch, touches.contains(touch) else { return }
        let samples = event?.coalescedTouches(for: touch) ?? [touch]
        for sample in samples {
            interaction.markMoved(to: sample.location(in: self), force: Self.force(of: sample), time: sample.timestamp)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = markingTouch, touches.contains(touch) else { return }
        markingTouch = nil
        // The lift sample's falling force is not fed to the depth tracker, and
        // estimated force updates that arrive after lift are not observed.
        interaction.markEnded(at: touch.location(in: self))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = markingTouch, touches.contains(touch) else { return }
        markingTouch = nil
        interaction.markCancelled()
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let kind = Self.kind(of: touch)
        if gestureRecognizer === tapRecognizer {
            guard kind != .pencil, interaction.tool == .component else { return false }
            lastTapKind = kind
            return true
        }
        switch kind {
        case .pencil:
            // Pencil never moves the camera.
            return false
        case .pointer:
            // A pointer drag pans with the hand tool and marks otherwise.
            return gestureRecognizer === panRecognizer && interaction.tool == .hand
        case .finger:
            return true
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        let camera: [UIGestureRecognizer] = [panRecognizer, scrollRecognizer, pinchRecognizer]
        return camera.contains { $0 === gestureRecognizer } && camera.contains { $0 === other }
    }

    // MARK: - Helpers

    private static func kind(of touch: UITouch) -> InputKind {
        switch touch.type {
        case .pencil: .pencil
        case .indirectPointer: .pointer
        default: .finger
        }
    }

    /// Normalized Pencil force; other input has none.
    private static func force(of touch: UITouch) -> Double? {
        guard touch.type == .pencil else { return nil }
        return PressureDepthTracker.normalizedForce(force: touch.force, maximumPossibleForce: touch.maximumPossibleForce)
    }
}
#endif
