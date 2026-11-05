@testable import CanvasKit
import CoreGraphics
import Testing

@Suite("ScrollPhysics")
struct ScrollPhysicsTests {
    @Test func rangeKeepsContentInView() {
        // Content 0...1000 at 50 % in a 1000 pt view: 120 pt stay visible at either end.
        let range = ScrollPhysics.offsetRange(content: 0...1000, zoom: 0.5, viewLength: 1000)
        #expect(abs(range.lowerBound - (120 - 500)) < 0.001)
        #expect(abs(range.upperBound - (1000 - 120)) < 0.001)
    }

    @Test func smallContentKeepsAllOfItself() {
        // 40 pt of content cannot keep 120 pt in view: all of it must stay.
        let range = ScrollPhysics.offsetRange(content: 0...40, zoom: 1, viewLength: 1000)
        #expect(range.lowerBound == 0)
        #expect(range.upperBound == 960)
    }

    @Test func movementInsideRangeIsFree() {
        #expect(ScrollPhysics.resisted(delta: 30, at: 0, in: -100...100, viewLength: 1000) == 30)
        #expect(ScrollPhysics.resisted(delta: -30, at: 100, in: -100...100, viewLength: 1000) == -30)
    }

    @Test func movementPastTheEdgeResistsMoreTheFurtherItGoes() {
        let near = ScrollPhysics.resisted(delta: 10, at: 110, in: -100...100, viewLength: 1000)
        let far = ScrollPhysics.resisted(delta: 10, at: 400, in: -100...100, viewLength: 1000)
        #expect(near < 10 && far < near && far > 0)
        // Moving back toward the content is never resisted.
        #expect(ScrollPhysics.resisted(delta: -10, at: 400, in: -100...100, viewLength: 1000) == -10)
    }

    @Test func coastingSlowsDownAndComesToRest() {
        var axis = ScrollPhysics.Axis(position: 0, velocity: 2000)
        var frames = 0
        while ScrollPhysics.step(&axis, in: -10_000...10_000, dt: 1.0 / 60) && frames < 2000 { frames += 1 }
        #expect(frames < 2000)
        #expect(axis.velocity == 0)
        // v / -ln(0.998 per ms) ≈ 1000 pt of travel.
        #expect(axis.position > 800 && axis.position < 1100)
    }

    @Test func fastCoastPastTheEdgeSpringsBackInside() {
        let range: ClosedRange<CGFloat> = -100...100
        var axis = ScrollPhysics.Axis(position: 90, velocity: 3000)
        var frames = 0
        var farthest: CGFloat = 0
        while ScrollPhysics.step(&axis, in: range, dt: 1.0 / 60) && frames < 2000 {
            farthest = max(farthest, axis.position)
            frames += 1
        }
        #expect(frames < 2000)
        #expect(farthest > range.upperBound)
        #expect(axis.position == range.upperBound)
    }

    @Test func releaseFarOutsideReturnsToTheEdge() {
        var axis = ScrollPhysics.Axis(position: -400, velocity: 0)
        var frames = 0
        while ScrollPhysics.step(&axis, in: -100...100, dt: 1.0 / 60) && frames < 2000 { frames += 1 }
        #expect(frames < 2000)
        #expect(axis.position == -100)
    }
}
