@testable import CanvasKit
import CoreGraphics
import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("StrokeClassifier")
struct StrokeClassifierTests {
    let frame = CGRect(x: 0, y: 0, width: 420, height: 840)

    private func shape(_ points: [CGPoint], _ kind: MarkKind, zoom: Double = 1) -> AnnotationShape? {
        StrokeClassifier.shape(for: points, kind: kind, zoom: zoom, in: frame)
    }

    @Test func circleBecomesLasso() throws {
        var points = (0..<40).map { index -> CGPoint in
            let angle = Double(index) / 40 * 2 * .pi
            return CGPoint(x: 200 + 60 * cos(angle), y: 300 + 60 * sin(angle))
        }
        points.append(CGPoint(x: points[0].x + 5, y: points[0].y))
        let result = try #require(shape(points, .region))
        guard case .lasso(let lasso) = result else {
            Issue.record("expected lasso, got \(result)")
            return
        }
        #expect(lasso.count >= 3)
        for point in lasso {
            #expect((0.0...1.0).contains(point.x))
            #expect((0.0...1.0).contains(point.y))
        }
    }

    @Test func diagonalDragBecomesRegion() throws {
        let points = line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 250, y: 260))
        let result = try #require(shape(points, .region))
        guard case .region(let rect) = result else {
            Issue.record("expected region, got \(result)")
            return
        }
        #expect(abs(rect.x - 100.0 / 420) < 1e-9)
        #expect(abs(rect.y - 100.0 / 840) < 1e-9)
        #expect(abs(rect.width - 150.0 / 420) < 1e-9)
        #expect(abs(rect.height - 160.0 / 840) < 1e-9)
    }

    @Test(arguments: [
        ([CGPoint(x: 0, y: 0), CGPoint(x: 114.5, y: 0), CGPoint(x: 29, y: 0)], CGFloat(1), true),
        ([CGPoint(x: 0, y: 0), CGPoint(x: 115.5, y: 0), CGPoint(x: 31, y: 0)], CGFloat(1), false),
        ([CGPoint(x: 0, y: 0), CGPoint(x: 270, y: 0), CGPoint(x: 40, y: 0)], CGFloat(1), true),
        ([CGPoint(x: 0, y: 0), CGPoint(x: 114.5, y: 0), CGPoint(x: 29, y: 0)], CGFloat(2), false),
    ])
    func closedLoopThresholds(points: [CGPoint], scale: CGFloat, expected: Bool) {
        #expect(StrokeClassifier.isClosedLoop(points, scale: scale) == expected)
    }

    @Test func closedLoopNeedsThreePoints() {
        #expect(!StrokeClassifier.isClosedLoop([.zero, .zero], scale: 1))
        #expect(!StrokeClassifier.isClosedLoop([], scale: 1))
    }

    @Test func tinyRegionDragIsIgnored() {
        #expect(shape(line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 120, y: 120)), .region) == nil)
    }

    @Test func tinyPenStrokeIsIgnored() {
        #expect(shape(line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 120, y: 120)), .pen) == nil)
    }

    @Test func horizontalPenLineIsStroke() throws {
        let result = try #require(shape(line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 200, y: 100)), .pen))
        guard case .stroke(let points) = result else {
            Issue.record("expected stroke, got \(result)")
            return
        }
        #expect(points.count >= 2)
    }

    @Test func thinRegionDragIsIgnored() {
        #expect(shape(line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 200, y: 104)), .region) == nil)
    }

    @Test func thresholdsAreInScreenPointsNotWorldUnits() {
        let points = line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 120, y: 120))
        if case .region = shape(points, .region, zoom: 2) {} else {
            Issue.record("a 20x20 world drag at zoom 2 should be a region")
        }
        #expect(shape(points, .region, zoom: 1) == nil)
    }

    @Test func shortArrowIsIgnored() {
        #expect(shape(line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 120, y: 110)), .arrow) == nil)
    }

    @Test func longArrowKeepsEndpoints() {
        let result = shape(line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 140, y: 100)), .arrow)
        #expect(result == .arrow(from: NPoint(x: 100.0 / 420, y: 100.0 / 840), to: NPoint(x: 140.0 / 420, y: 100.0 / 840)))
    }

    @Test(arguments: [MarkKind.region, .arrow, .pen])
    func tapProducesNothing(kind: MarkKind) {
        let p = CGPoint(x: 200, y: 200)
        #expect(shape([p, p], kind) == nil)
    }

    @Test func regionIsClampedToSnapshot() throws {
        let result = try #require(shape(line(from: CGPoint(x: -50, y: -50), to: CGPoint(x: 100, y: 100)), .region))
        guard case .region(let rect) = result else {
            Issue.record("expected region, got \(result)")
            return
        }
        #expect(rect.x == 0)
        #expect(rect.y == 0)
    }

    @Test func simplifiedKeepsEndpointsAndDropsDensePoints() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 3, y: 0), CGPoint(x: 3.2, y: 0)]
        let result = StrokeClassifier.simplified(points, spacing: 2)
        #expect(result.first == CGPoint(x: 0, y: 0))
        #expect(result.last == CGPoint(x: 3.2, y: 0))
        #expect(!result.contains(CGPoint(x: 0.5, y: 0)))
        #expect(!result.contains(CGPoint(x: 1, y: 0)))
    }

    @Test func singlePointOrZoomZeroIsIgnored() {
        #expect(shape([CGPoint(x: 1, y: 1)], .pen) == nil)
        #expect(shape(line(from: .zero, to: CGPoint(x: 100, y: 100)), .region, zoom: 0) == nil)
    }
}
