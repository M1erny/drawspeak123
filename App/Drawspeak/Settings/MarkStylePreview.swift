import DrawspeakCore
import SwiftUI

struct MarkStylePreview: View {
    let style: AnnotationStyle

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Theme.canvas)
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(width: 100, height: 10)
                RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(height: 36)
            }
            .padding(24)
            Rectangle()
                .stroke(Theme.annotationHalo, lineWidth: style.haloWidth)
                .overlay { Rectangle().stroke(Theme.annotation, lineWidth: style.lineWidth) }
                .padding(.horizontal, 48).padding(.vertical, 28)
                .overlay(alignment: .topLeading) {
                    Text("1")
                        .font(.system(size: style.pinFontSize, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: style.pinSize, height: style.pinSize)
                        .background(Theme.annotation, in: .circle)
                        .padding(AnnotationStyle.pinRingWidth)
                        .background(Theme.annotationHalo, in: .circle)
                        .offset(x: 48 - style.pinSize / 2 - AnnotationStyle.pinRingWidth,
                                y: 28 - style.pinSize / 2 - AnnotationStyle.pinRingWidth)
                }
        }
        .frame(height: 120)
        .accessibilityLabel("Mark preview")
        .accessibilityElement(children: .ignore)
    }
}
