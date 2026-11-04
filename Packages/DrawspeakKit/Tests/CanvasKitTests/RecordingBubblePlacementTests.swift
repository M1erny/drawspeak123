@testable import CanvasKit
import CoreGraphics
import Testing

@Suite("Recording bubble placement")
struct RecordingBubblePlacementTests {
    @Test func keepsBubbleInsideAllViewportEdges() {
        let bounds = CGRect(x: 16, y: 72, width: 340, height: 600)
        let bubble = CGSize(width: 280, height: 80)
        for pin in [CGPoint(x: 16, y: 72), CGPoint(x: 356, y: 672), CGPoint(x: -80, y: 900)] {
            let origin = RecordingBubblePlacement.origin(pin: pin, bubble: bubble, bounds: bounds)
            #expect(bounds.contains(CGRect(origin: origin, size: bubble)))
        }
    }

    @Test func flipsToLeftWhenRightHasNoRoom() {
        let origin = RecordingBubblePlacement.origin(pin: CGPoint(x: 700, y: 200),
            bubble: CGSize(width: 280, height: 80), bounds: CGRect(x: 0, y: 0, width: 800, height: 600))
        #expect(origin == CGPoint(x: 394, y: 160))
    }
}
