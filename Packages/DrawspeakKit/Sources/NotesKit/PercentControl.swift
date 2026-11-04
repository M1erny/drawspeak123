import SwiftUI
import DrawspeakCore

struct PercentControl: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack {
            Stepper("\(title): \(Int(value))%", value: $value, in: 0...100, step: 1)
                .frame(minHeight: Theme.minTarget)

        }
    }
}

#Preview { PercentControl(title: "Width", value: .constant(40)) }
