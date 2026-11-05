import CoreGraphics
import Foundation

/// How the canvas behaves like a system scroll view (HIG, Scroll views: "If you build custom
/// scrolling for a view, make sure your scroll indicators use the elastic behavior that people
/// expect"): content can only be panned until a little of it is left in view, a pan past that
/// resists, and a lifted finger carries on and settles back inside.
nonisolated enum ScrollPhysics {
    /// Screen points of content that always stay in view, so the canvas can never be scrolled empty.
    static let keptInView: CGFloat = 120
    /// `UIScrollView.DecelerationRate.normal`: the fraction of speed kept every millisecond.
    static let decelerationPerMillisecond = 0.998
    /// Below this speed (points per second) a coast ends.
    static let stopSpeed: CGFloat = 12
    /// Stiffness of the spring that pulls the canvas back from past its edge; critically damped.
    static let springStiffness: CGFloat = 200

    struct Axis: Equatable {
        var position: CGFloat = 0
        var velocity: CGFloat = 0
    }

    /// The camera offsets the canvas may rest at on one axis: `content` is the world extent on
    /// that axis, `viewLength` the visible length. At least `keptInView` of the content stays on screen.
    static func offsetRange(content: ClosedRange<CGFloat>, zoom: Double, viewLength: CGFloat) -> ClosedRange<CGFloat> {
        let zoom = CGFloat(zoom)
        let kept = min(keptInView, max(viewLength / 2, 0), max((content.upperBound - content.lowerBound) * zoom, 1))
        let lower = kept - content.upperBound * zoom
        let upper = viewLength - kept - content.lowerBound * zoom
        return lower <= upper ? lower...upper : upper...upper
    }

    /// A finger movement of `delta` at `position`: free inside `range`, and shrinking with how far
    /// past an edge the canvas already is, so it feels attached to the finger but stretched.
    static func resisted(delta: CGFloat, at position: CGFloat, in range: ClosedRange<CGFloat>, viewLength: CGFloat) -> CGFloat {
        let excess: CGFloat
        if position > range.upperBound, delta > 0 { excess = position - range.upperBound }
        else if position < range.lowerBound, delta < 0 { excess = range.lowerBound - position }
        else { return delta }
        let stretch = max(viewLength / 2, 1)
        let remaining = max(1 - excess / stretch, 0)
        return delta * max(remaining * remaining, 0.02)
    }

    /// Advances one axis by `dt` seconds. Inside the range it decelerates; outside it springs back.
    /// Returns false once it has come to rest.
    static func step(_ axis: inout Axis, in range: ClosedRange<CGFloat>, dt: Double) -> Bool {
        let dt = min(max(dt, 0), 1.0 / 30)
        let target = min(max(axis.position, range.lowerBound), range.upperBound)
        if axis.position == target {
            guard abs(axis.velocity) >= stopSpeed else {
                axis.velocity = 0
                return false
            }
            axis.velocity *= CGFloat(pow(decelerationPerMillisecond, dt * 1000))
            axis.position += axis.velocity * CGFloat(dt)
            return true
        }
        let displacement = axis.position - target
        let damping = 2 * springStiffness.squareRoot()
        axis.velocity += (-springStiffness * displacement - damping * axis.velocity) * CGFloat(dt)
        axis.position += axis.velocity * CGFloat(dt)
        let next = axis.position - min(max(axis.position, range.lowerBound), range.upperBound)
        if abs(next) < 0.3, abs(axis.velocity) < 8 {
            axis.position = min(max(axis.position, range.lowerBound), range.upperBound)
            axis.velocity = 0
            return false
        }
        return true
    }

    /// Whether `position` lies past either end of `range`.
    static func isOutside(_ position: CGFloat, _ range: ClosedRange<CGFloat>) -> Bool {
        position < range.lowerBound || position > range.upperBound
    }
}
