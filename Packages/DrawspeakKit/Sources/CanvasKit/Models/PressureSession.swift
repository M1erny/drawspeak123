import CoreGraphics
import Foundation
import HTMLKit

/// One Pencil press with the component tool, from touch down to lift.
struct PressureSession {
    let token = UUID()
    let canvasId: UUID
    let slotId: String
    let snapshotId: String
    let frame: CGRect
    let start: CGPoint
    let inspector: DOMInspector
    /// Set once the probe returns the element chain.
    var tracker: PressureDepthTracker?
    var selection: ComponentSelection?
    /// The latest force sample, replayed into the tracker when the probe returns.
    var lastSample: (force: Double, time: TimeInterval)?
    /// Force while the committed depth was held; recorded with the target.
    var stableForce: Double?
    /// The Pencil lifted before the probe returned.
    var liftPending = false
}
