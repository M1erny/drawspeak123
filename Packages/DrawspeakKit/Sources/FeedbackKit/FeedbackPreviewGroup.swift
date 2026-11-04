import DrawspeakCore

struct FeedbackPreviewGroup: Identifiable, Equatable {
    let id: String
    let snapshot: Snapshot?
    let title: String
    let notes: [Note]
    let items: [BatchItem]
}
