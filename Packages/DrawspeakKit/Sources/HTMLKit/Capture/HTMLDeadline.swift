import Foundation

/// Runs main-actor work with a time limit. The caller resumes at the limit even
/// when the work is stuck in a callback that never answers.
final class HTMLDeadline<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, any Error>?
    private var work: Task<Void, Never>?
    private var timer: Task<Void, Never>?

    static func run(
        _ limit: Duration,
        timeoutError: HTMLKitError,
        operation: @escaping @MainActor @Sendable () async throws -> Value
    ) async throws -> Value {
        let deadline = HTMLDeadline<Value>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                deadline.start(continuation, limit: limit, timeoutError: timeoutError, operation: operation)
            }
        } onCancel: {
            Task { @MainActor in
                deadline.finish(.failure(CancellationError()))
            }
        }
    }

    private func start(
        _ continuation: CheckedContinuation<Value, any Error>,
        limit: Duration,
        timeoutError: HTMLKitError,
        operation: @escaping @MainActor @Sendable () async throws -> Value
    ) {
        self.continuation = continuation
        work = Task {
            do {
                finish(.success(try await operation()))
            } catch {
                finish(.failure(error))
            }
        }
        timer = Task {
            do {
                try await Task.sleep(for: limit)
                finish(.failure(timeoutError))
            } catch {}
        }
    }

    private func finish(_ result: Result<Value, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        work?.cancel()
        timer?.cancel()
        continuation.resume(with: result)
    }
}
