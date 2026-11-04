#if DEBUG
import Foundation

/// Launch arguments for simulator screenshots: `-DrawspeakOpen <state>`.
enum DebugLaunch {
    static var requestedState: DebugOpenState? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-DrawspeakOpen"), index + 1 < arguments.count else { return nil }
        return DebugOpenState(argument: arguments[index + 1])
    }
}
#endif
