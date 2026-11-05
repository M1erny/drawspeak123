import FeedbackKit
import Testing

@Suite("FeedbackLimitError")
struct FeedbackLimitErrorTests {
    @Test func messagesResolveInflectionMarkup() throws {
        let one = try #require(FeedbackLimitError.tooManyAttachments(count: 9, snapshotsToRemove: 1).errorDescription)
        let five = try #require(FeedbackLimitError.tooManyAttachments(count: 13, snapshotsToRemove: 5).errorDescription)
        let up = try #require(FeedbackLimitError.tooManySnapshots(max: 6).errorDescription)
        for message in [one, five, up] {
            #expect(!message.contains("^["))
            #expect(!message.contains("inflect"))
        }
        #expect(one == "Too many attachments (9 of 8). Deselect comments on 1 screen.")
        #expect(five == "Too many attachments (13 of 8). Deselect comments on 5 screens.")
        #expect(up == "Select comments on up to 6 screens.")
    }
}
