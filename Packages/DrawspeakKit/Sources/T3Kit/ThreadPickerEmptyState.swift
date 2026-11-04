import SwiftUI

struct ThreadPickerEmptyState: View {
    let loading: Bool
    let isEmpty: Bool
    let isSearching: Bool
    let hasError: Bool

    var body: some View {
        if isEmpty && !hasError {
            if loading {
                ProgressView()
                    .accessibilityLabel(Text("Loading Threads", bundle: .module))
            } else if isSearching {
                ContentUnavailableView.search
            } else {
                ContentUnavailableView {
                    Label {
                        Text("No Threads", bundle: .module)
                    } icon: {
                        Image(systemName: "bubble.left.and.bubble.right")
                    }
                } description: {
                    Text("Create a thread in T3 Code on your Mac.", bundle: .module)
                }
            }
        }
    }
}
