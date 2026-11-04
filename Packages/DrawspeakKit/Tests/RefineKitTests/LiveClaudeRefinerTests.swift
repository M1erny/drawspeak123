import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers
import DrawspeakCore
import Testing
@testable import RefineKit

@Suite(.enabled(if: !(ProcessInfo.processInfo.environment["DRAWSPEAK_LIVE_ANTHROPIC_KEY"] ?? "").isEmpty))
struct LiveClaudeRefinerTests {
    @Test func polishReview() async throws {
        let key = try #require(ProcessInfo.processInfo.environment["DRAWSPEAK_LIVE_ANTHROPIC_KEY"])
        let context = RefineContext(screenTitle: "Checkout", versionLabel: "synthetic", markKind: "rectangle", componentLabel: "Pay", language: "pol")
        let result = try await ClaudeRefiner(keyStore: .init(fixedKey: key)).refine(
            transcript: "Są ręce, kurwa. No, paluszki. Bardzo źle to wygląda.",
            regionPNG: try buttonPNG(), context: context
        )
        print("LiveClaudeRefinerTests result: \(result)")
        #expect(!result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let lower = result.lowercased()
        #expect(!lower.contains("kurw"))
        // Common Polish words/inflections; avoid requiring one exact model answer.
        #expect(["przycisk", "wygląd", "wyglad", "pal", "rę", "nie", "popraw", "usu", "zmie", "zwię", "zwięk", "interfejs", "element"].contains { lower.contains($0) })
    }

    private func buttonPNG() throws -> Data {
        let canvas = try #require(CGContext(data: nil, width: 160, height: 80, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        canvas.setFillColor(CGColor(gray: 1, alpha: 1))
        canvas.fill(CGRect(x: 0, y: 0, width: 160, height: 80))
        canvas.setFillColor(CGColor(gray: 0.7, alpha: 1))
        canvas.fill(CGRect(x: 20, y: 20, width: 120, height: 40))
        let label = NSAttributedString(string: "Pay", attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 18, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
        ])
        canvas.textPosition = CGPoint(x: 64, y: 33)
        CTLineDraw(CTLineCreateWithAttributedString(label), canvas)
        let image = try #require(canvas.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
