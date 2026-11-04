import DrawspeakCore
import Foundation
import Testing
@testable import HTMLKit

struct HTMLCaptureSizeTests {
    @Test func capturesTallBoardsAtViewportWidth() {
        let size = HTMLCaptureSize(viewport: Viewport(width: 1440, height: 1688, deviceScaleFactor: 2), contentHeightCSS: 5000)
        #expect(size.widthCSS == 1440)
        #expect(size.heightCSS == 5000)
        #expect(size.pixelWidth == 2880)
        #expect(size.pixelHeight == 10000)
    }

    @Test func capsHeightWithoutShrinkingLayoutWidth() {
        let size = HTMLCaptureSize(viewport: Viewport(width: 1440, height: 1688, deviceScaleFactor: 1), contentHeightCSS: 20000)
        #expect(size.widthCSS == 1440)
        #expect(size.heightCSS == 8000)
        #expect(size.pixelWidth == 1440)
        #expect(size.pixelHeight == 8000)
    }

    @Test func reducesRasterScaleToStayWithinPixelBudget() {
        let size = HTMLCaptureSize(viewport: Viewport(width: 1440, height: 1688, deviceScaleFactor: 3), contentHeightCSS: 9000)
        #expect(size.heightCSS == 8000)
        #expect(size.pixelWidth < 4320)
        #expect(size.pixelHeight < 24000)
        #expect(size.pixelWidth * size.pixelHeight <= HTMLCaptureSize.maximumPixels)
        let scale = Double(size.pixelWidth) / size.widthCSS
        #expect(abs(Double(size.pixelHeight) - size.heightCSS * scale) < 6)
    }

    @Test func preservesSmallAndFractionalContentHeight() {
        let size = HTMLCaptureSize(viewport: Viewport(width: 100, height: 800, deviceScaleFactor: 2), contentHeightCSS: 120.2)
        #expect(size.heightCSS == 121)
        #expect(size.pixelWidth == 200)
        #expect(size.pixelHeight == 242)
    }

    @Test func sanitizesInvalidMeasurementsAndScale() {
        for scale in [Double.nan, .infinity, 0, -1] {
            let size = HTMLCaptureSize(viewport: Viewport(width: 100, height: 800, deviceScaleFactor: scale), contentHeightCSS: .nan)
            #expect(size.heightCSS == 800)
            #expect(size.pixelWidth == 100)
            #expect(size.pixelHeight == 800)
        }
    }

    @Test func neverExceedsBudgetForExtremeInputs() {
        let size = HTMLCaptureSize(viewport: Viewport(width: Int.max, height: 1, deviceScaleFactor: 100), contentHeightCSS: 1)
        #expect(size.pixelWidth * size.pixelHeight <= HTMLCaptureSize.maximumPixels)
        #expect(size.pixelHeight >= 1)
    }

    @Test func tallCapturesAreSlicedBelowTheTextureLimit() {
        let size = HTMLCaptureSize(viewport: Viewport(width: 1440, height: 844, deviceScaleFactor: 2), contentHeightCSS: 12_000)
        let tiles = size.tiles()
        #expect(tiles.count > 1)
        var pixelY = 0
        var cssY = 0.0
        for tile in tiles {
            #expect(tile.pixelHeight <= HTMLCaptureSize.maximumTilePixelHeight)
            #expect(tile.pixelMinY == pixelY)
            #expect(tile.minYCSS == cssY)
            pixelY += tile.pixelHeight
            cssY += tile.heightCSS
        }
        #expect(pixelY == size.pixelHeight)
        #expect(cssY == size.heightCSS)
    }

    @Test func shortCapturesAreOneTile() {
        let size = HTMLCaptureSize(viewport: Viewport(width: 1440, height: 844, deviceScaleFactor: 2), contentHeightCSS: 1_722)
        #expect(size.tiles() == [HTMLCaptureTile(minYCSS: 0, heightCSS: 1_722, pixelMinY: 0, pixelHeight: 3_444)])
    }
}
