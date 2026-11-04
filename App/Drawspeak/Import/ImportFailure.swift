import DrawspeakCore
import Foundation

nonisolated struct ImportFailure: Error {
    var message: String

    init(message: String) {
        self.message = message
    }

    init(_ error: any Error) {
        switch error {
        case Workspace.ImportError.tooLarge(let limit):
            message = String(localized: "The file is larger than \(limit) MiB.", comment: "Maximum file size in mebibytes.")
        case Workspace.ImportError.invalidViewport:
            message = String(localized: "This HTML's viewport is too large.")
        case Workspace.ImportError.unsupportedType:
            message = String(localized: "Use PNG, JPEG, WebP or HTML.")
        case let failure as ImportFailure:
            message = failure.message
        default:
            message = String(localized: "Can't import this file.")
        }
    }

    static var unreadable: ImportFailure {
        ImportFailure(message: String(localized: "Can't read this file."))
    }
}
