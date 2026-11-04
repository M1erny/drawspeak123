import DrawspeakCore

struct ThreadProjectGroup: Identifiable, Equatable {
    // nil represents ungrouped threads and cannot collide with a server project ID.
    let id: String?
    let title: String
    var threads: [ThreadSummary]
}
