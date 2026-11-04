#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

struct LaneTitle: View {
    let lane: Lane
    var body: some View {
        if lane.key.isNow {
            Text("Now", bundle: .module).font(.headline)
        } else {
            Text(lane.title).font(.headline)
        }
    }
}
#endif
