import SwiftUI

struct FeedbackFixtureImage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Checkout", bundle: .module).font(.largeTitle.bold())
            Text("Your order", bundle: .module).font(.title2)
            Divider()
            Text("One thoughtful review", bundle: .module).font(.body)
            Spacer()
            Text("Continue", bundle: .module).font(.headline).padding().frame(maxWidth: .infinity).background(.blue, in: .rect(cornerRadius: 12)).foregroundStyle(.white)
        }.padding(40).background(.white).foregroundStyle(.black)
    }
}
