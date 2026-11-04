import DrawspeakCore
import Foundation
import HTMLKit

enum HTMLCaptureAdapter {
    static func capture(html: Data, policy: RenderPolicy, viewport: Viewport) async throws -> (png: Data, width: Int, height: Int) {
        let result = try await HTMLCapture.capture(html: html, policy: policy, viewport: viewport)
        return (result.pngData, result.pixelWidth, result.pixelHeight)
    }
}
