#if DEBUG && canImport(UIKit)
import SwiftUI

/// A simple phone-sized mock screen, rendered to PNG for previews.
struct MockScreenArt: View {
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("north / studio")
                .font(.system(size: 15, weight: .bold))
            Text(title)
                .font(.system(size: 30, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.92))
                .frame(height: 180)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.95))
                .frame(height: 120)
            Spacer()
            Text("Pay $48")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(accent, in: .rect(cornerRadius: 14))
        }
        .padding(24)
        .frame(width: 390, height: 844)
        .background(.white)
    }

    /// PNG bytes at 1× scale.
    func pngData() -> Data? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 1
        return renderer.uiImage?.pngData()
    }
}
#endif
