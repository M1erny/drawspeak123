import DrawspeakCore
import SwiftUI

struct MarksSettingsSection: View {
    @AppStorage("drawspeak.markLineWidth") private var lineWidth = Double(AnnotationStyle.standard.lineWidth)
    @AppStorage("drawspeak.pinSize") private var pinSize = Double(AnnotationStyle.standard.pinSize)

    var body: some View {
        Section("Marks") {
            MarkStylePreview(style: AnnotationStyle(lineWidth: lineWidth, pinSize: pinSize))
            VStack(alignment: .leading) {
                Text("Line Width")
                Slider(value: $lineWidth, in: Double(AnnotationStyle.lineWidthRange.lowerBound)...Double(AnnotationStyle.lineWidthRange.upperBound), step: 0.5) {
                    Text("Line Width")
                }
            }
            VStack(alignment: .leading) {
                Text("Number Size")
                Slider(value: $pinSize, in: Double(AnnotationStyle.pinSizeRange.lowerBound)...Double(AnnotationStyle.pinSizeRange.upperBound), step: 2) {
                    Text("Number Size")
                }
            }
            Button("Reset") {
                lineWidth = Double(AnnotationStyle.standard.lineWidth)
                pinSize = Double(AnnotationStyle.standard.pinSize)
            }
        }
    }
}
