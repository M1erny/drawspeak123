import DrawspeakCore
import Foundation

struct ImportFailure: Error {
    var message: String

    init(message: String) {
        self.message = message
    }

    init(_ error: any Error) {
        switch error {
        case Workspace.ImportError.tooLarge(let limit): message = "The file is larger than \(limit) MiB."
        case Workspace.ImportError.unsupportedType: message = "Drawspeak imports PNG, JPEG, WebP and self-contained HTML."
        case let failure as ImportFailure: message = failure.message
        default: message = "The file could not be imported."
        }
    }
}
