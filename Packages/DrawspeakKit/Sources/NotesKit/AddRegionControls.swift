import SwiftUI

struct AddRegionControls: View {
    @Binding var x: Double
    @Binding var y: Double
    @Binding var width: Double
    @Binding var height: Double
    @Binding var oval: Bool

    var body: some View {
        VStack {
            PercentControl(title: String(localized: "X", bundle: .module), value: $x)
            PercentControl(title: String(localized: "Y", bundle: .module), value: $y)
            PercentControl(title: String(localized: "Width", bundle: .module), value: $width)
            PercentControl(title: String(localized: "Height", bundle: .module), value: $height)
            Picker(selection: $oval) {
                Text("Rectangle", bundle: .module).tag(false)
                Text("Oval", bundle: .module).tag(true)
            } label: { Text("Shape", bundle: .module) }
        }
    }
}
