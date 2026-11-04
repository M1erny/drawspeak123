import SwiftUI
import DrawspeakCore

struct PercentControl: View {
    let title: String
    @Binding var value: Double
    var body: some View {
        Stepper(value: $value, in: 0...100, step: 1) {
            Text("\(title): \(value / 100, format: .percent)", bundle: .module)
        }
        .frame(minHeight: Theme.minTarget)
    }
}
