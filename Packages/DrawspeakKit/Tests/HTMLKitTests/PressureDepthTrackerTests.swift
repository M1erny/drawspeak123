import Testing
@testable import HTMLKit

struct PressureDepthTrackerTests {
    /// Feeds samples 10 ms apart, starting at `start`, and returns the last live depth.
    @discardableResult
    private func feed(_ tracker: inout PressureDepthTracker, _ forces: [Double], from start: Double, step: Double = 0.01) -> Int {
        var depth = tracker.depth
        for (index, force) in forces.enumerated() {
            depth = tracker.update(force: force, at: start + Double(index) * step)
        }
        return depth
    }

    @Test func lightPressureSelectsTheHitElement() {
        var tracker = PressureDepthTracker(levels: 4)
        #expect(tracker.update(force: 0.05, at: 0) == 0)
        #expect(tracker.update(force: 0.2, at: 0.2) == 0)
        #expect(tracker.update(force: 0.26, at: 0.4) == 0)
        #expect(tracker.commit() == 0)
    }

    @Test func thresholdsAreEvenlySpaced() {
        let tracker = PressureDepthTracker(levels: 4)
        #expect(tracker.threshold(for: 1) == 0.25)
        #expect(tracker.threshold(for: 2) == 0.5)
        #expect(tracker.threshold(for: 3) == 0.75)
    }

    @Test func rampUpWalksParentsToTheRoot() {
        var tracker = PressureDepthTracker(levels: 4)
        var depths: [Int] = []
        for step in 0...20 {
            depths.append(tracker.update(force: Double(step) / 20, at: Double(step) * 0.2))
        }
        #expect(depths.first == 0)
        #expect(depths.last == 3)
        #expect(depths == depths.sorted())
        #expect(Set(depths) == [0, 1, 2, 3])
        #expect(tracker.commit() == 3)
    }

    @Test func crossingNeedsHalfTheBandAboveTheThreshold() {
        var tracker = PressureDepthTracker(levels: 2, band: 0.1)
        #expect(tracker.update(force: 0.54, at: 0) == 0)
        #expect(tracker.update(force: 0.56, at: 0.01) == 1)
        #expect(tracker.update(force: 0.46, at: 0.02) == 1)
        #expect(tracker.update(force: 0.44, at: 0.03) == 0)
    }

    @Test func jitterWithinTheBandDoesNotFlip() {
        var tracker = PressureDepthTracker(levels: 4)
        tracker.update(force: 0.6, at: 0)
        #expect(tracker.depth == 2)
        let jitter = [0.49, 0.51, 0.485, 0.515, 0.5, 0.482, 0.518, 0.49]
        for (index, force) in jitter.enumerated() {
            #expect(tracker.update(force: force, at: 0.01 * Double(index + 1)) == 2)
        }
        var low = PressureDepthTracker(levels: 4)
        low.update(force: 0.4, at: 0)
        for (index, force) in jitter.enumerated() {
            #expect(low.update(force: force, at: 0.01 * Double(index + 1)) == 1)
        }
    }

    @Test func releaseAfterQuickForceDropKeepsTheLastStableDepth() {
        var tracker = PressureDepthTracker(levels: 4)
        feed(&tracker, [0.1, 0.3, 0.55, 0.7, 0.8, 0.8], from: 0, step: 0.05)
        // Held at the root for 300 ms.
        feed(&tracker, Array(repeating: 0.82, count: 10), from: 0.3, step: 0.03)
        #expect(tracker.stableDepth == 3)
        // Lifting: the force falls through every level within 40 ms.
        let lifted = feed(&tracker, [0.6, 0.4, 0.2, 0.02], from: 0.6)
        #expect(lifted == 0)
        #expect(tracker.commit() == 3)
    }

    @Test func stableDepthNeedsTheFullInterval() {
        var tracker = PressureDepthTracker(levels: 3, stableInterval: 0.12)
        tracker.update(force: 0.5, at: 0)
        #expect(tracker.depth == 1)
        tracker.update(force: 0.5, at: 0.1)
        #expect(tracker.stableDepth == 0)
        tracker.update(force: 0.5, at: 0.12)
        #expect(tracker.stableDepth == 1)
        #expect(tracker.commit() == 1)
    }

    @Test func briefPeakDoesNotBecomeStable() {
        var tracker = PressureDepthTracker(levels: 3)
        tracker.update(force: 0.1, at: 0)
        tracker.update(force: 0.1, at: 0.2)
        tracker.update(force: 0.9, at: 0.21)
        tracker.update(force: 0.1, at: 0.25)
        #expect(tracker.commit() == 0)
    }

    @Test func singleLevelIsAlwaysTheHitElement() {
        var tracker = PressureDepthTracker(levels: 1)
        for (index, force) in [0.0, 0.5, 1.0, 0.99, 0.2].enumerated() {
            #expect(tracker.update(force: force, at: Double(index) * 0.2) == 0)
        }
        #expect(tracker.commit() == 0)
        #expect(PressureDepthTracker(levels: 0).levels == 1)
    }

    @Test func invalidSamplesAreIgnoredAndForceIsClamped() {
        var tracker = PressureDepthTracker(levels: 3)
        #expect(tracker.update(force: 5, at: 0) == 2)
        #expect(tracker.force == 1)
        #expect(tracker.update(force: .nan, at: 0.01) == 2)
        #expect(tracker.update(force: -1, at: 0.02) == 0)
        #expect(tracker.force == 0)
    }

    @Test func explicitSelectionIsStableAtOnce() {
        var tracker = PressureDepthTracker(levels: 5)
        tracker.select(depth: 3, at: 0)
        #expect(tracker.depth == 3)
        #expect(tracker.commit() == 3)
        tracker.select(depth: 9, at: 0.1)
        #expect(tracker.commit() == 4)
    }

    @Test func normalizedForceDividesByTheMaximum() {
        #expect(PressureDepthTracker.normalizedForce(force: 2, maximumPossibleForce: 4) == 0.5)
        #expect(PressureDepthTracker.normalizedForce(force: 0, maximumPossibleForce: 4) == 0)
        #expect(PressureDepthTracker.normalizedForce(force: 6, maximumPossibleForce: 4) == 1)
        #expect(PressureDepthTracker.normalizedForce(force: -1, maximumPossibleForce: 4) == 0)
        #expect(PressureDepthTracker.normalizedForce(force: 3, maximumPossibleForce: 0) == 0)
        #expect(PressureDepthTracker.normalizedForce(force: 3, maximumPossibleForce: -2) == 0)
        #expect(PressureDepthTracker.normalizedForce(force: .nan, maximumPossibleForce: 4) == 0)
    }
}
