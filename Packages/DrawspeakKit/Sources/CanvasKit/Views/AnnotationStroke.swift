#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

extension Path {
    func annotationStroke(width: CGFloat, halo: CGFloat) -> some View {
        stroke(Theme.annotationHalo, style: StrokeStyle(lineWidth: width + halo, lineCap: .round, lineJoin: .round))
            .overlay {
                stroke(Theme.annotation, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
    }
}
#endif
