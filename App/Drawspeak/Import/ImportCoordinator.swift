import DrawspeakCore
import Foundation
import HTMLKit
import ImageIO
import UniformTypeIdentifiers

/// Reads imported files and stores them as immutable snapshots.
@MainActor
struct ImportCoordinator {
    static let allowedTypes: [UTType] = [.png, .jpeg, .webP, .html]

    func read(_ url: URL) async -> Result<PendingImport, ImportFailure> {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return .failure(ImportFailure(message: "The file could not be read.")) }
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        let name = url.lastPathComponent
        let title = url.deletingPathExtension().lastPathComponent
        if type.conforms(to: .html) {
            guard data.count <= Workspace.maxHTMLBytes else { return .failure(ImportFailure(Workspace.ImportError.tooLarge(limitMiB: 2))) }
            let info = HTMLImport.inspect(data)
            do {
                let capture = try await HTMLCapture.capture(html: data, policy: .staticNoScript, viewport: info.suggestedViewport)
                return .success(PendingImport(
                    fileName: name, suggestedTitle: info.title ?? title, kind: .html, contentType: "text/html", data: data,
                    pixelSize: (capture.pixelWidth, capture.pixelHeight), viewport: info.suggestedViewport,
                    capture: capture.pngData, containsScripts: info.containsScripts
                ))
            } catch {
                return .failure(ImportFailure(message: "The HTML could not be rendered."))
            }
        }
        guard Self.allowedTypes.contains(where: { type.conforms(to: $0) }) else {
            return .failure(ImportFailure(Workspace.ImportError.unsupportedType))
        }
        guard data.count <= Workspace.maxImageBytes else { return .failure(ImportFailure(Workspace.ImportError.tooLarge(limitMiB: 10))) }
        guard let size = Self.pixelSize(of: data) else { return .failure(ImportFailure(message: "The image could not be decoded.")) }
        return .success(PendingImport(
            fileName: name, suggestedTitle: title, kind: .image, contentType: type.preferredMIMEType ?? "image/png", data: data,
            pixelSize: size, viewport: nil, capture: nil, containsScripts: false
        ))
    }

    func store(_ pending: PendingImport, target: Workspace.ImportTarget, in workspace: Workspace) throws -> Snapshot {
        try workspace.importArtifact(
            data: pending.data,
            kind: pending.kind,
            contentType: pending.contentType,
            fileName: pending.fileName,
            pixelSize: pending.pixelSize,
            viewport: pending.viewport,
            target: target,
            captureImage: pending.capture.map { ($0, "image/png") },
            renderPolicy: pending.kind == .html ? .staticNoScript : nil
        )
    }

    static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { return nil }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        return orientation >= 5 ? (height, width) : (width, height)
    }
}
