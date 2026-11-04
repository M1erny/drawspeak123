import DrawspeakCore
import SwiftUI

struct BannerView: View {
    let banner: CanvasBanner
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(banner.isError ? Theme.annotation : .green)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(banner.message)
                    .font(.subheadline.weight(.semibold))
                ForEach(banner.details, id: \.self) { detail in
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
            Spacer(minLength: 0)
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .frame(width: Theme.minTarget, height: Theme.minTarget)
        }
        .padding(.leading, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: 480)
        .paletteBackground()
        .accessibilityElement(children: .combine)
    }
}
