import Foundation

/// The API key header must never follow a redirect: the 3xx response becomes the result.
nonisolated final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    // The completion-handler form: the async form crashes the Swift 6.4 compiler's ObjC thunk lowering.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
