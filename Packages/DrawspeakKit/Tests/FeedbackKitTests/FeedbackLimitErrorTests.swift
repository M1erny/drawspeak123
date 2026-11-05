import FeedbackKit
import Testing

@Suite("FeedbackLimitError")
struct FeedbackLimitErrorTests {
    /// A review over the attachment limit is now split into several messages instead of refused,
    /// so no message mentions a count; none may show raw inflection markup either.
    @Test func messagesShowNoRawMarkup() throws {
        let errors: [FeedbackLimitError] = [.needsSplit, .missingHTML("a"), .textTooLong, .missingImage("a"), .renderingFailed]
        for error in errors {
            let message = try #require(error.errorDescription)
            #expect(!message.isEmpty)
            #expect(!message.contains("^["))
            #expect(!message.contains("inflect"))
        }
    }
}
