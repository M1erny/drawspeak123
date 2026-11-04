import DrawspeakCore
import Foundation
import HTMLKit
import ImageIO
import UniformTypeIdentifiers

/// Reads imported files and stores them as immutable snapshots.
@MainActor
struct ImportCoordinator {
    static let allowedTypes: [UTType] = [.png, .jpeg, .webP, .html]

    func read(_ url: URL, canvasId: UUID) async -> Result<PendingImport, ImportFailure> {
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        let limit = type.conforms(to: .html) ? Workspace.maxHTMLBytes : Workspace.maxImageBytes
        let loaded = await Self.readBounded(url, limit: limit)
        guard case .success(let data) = loaded else {
            if case .failure(let failure) = loaded { return .failure(failure) }
            return .failure(ImportFailure.unreadable)
        }
        let name = url.lastPathComponent
        let title = url.deletingPathExtension().lastPathComponent
        if type.conforms(to: .html) {
            let info = HTMLImport.inspect(data)
            do {
                let capture = try await HTMLCapture.capture(html: data, policy: .staticNoScript, viewport: info.suggestedViewport)
                return .success(PendingImport(
                    canvasId: canvasId, fileName: name, suggestedTitle: info.title ?? title, kind: .html, contentType: "text/html", data: data,
                    pixelSize: (capture.pixelWidth, capture.pixelHeight), viewport: info.suggestedViewport,
                    capture: capture.pngData, containsScripts: info.containsScripts
                ))
            } catch {
                return .failure(ImportFailure(message: String(localized: "Can't render this HTML.")))
            }
        }
        guard Self.allowedTypes.contains(where: { type.conforms(to: $0) }) else {
            return .failure(ImportFailure(Workspace.ImportError.unsupportedType))
        }
        guard let size = Self.pixelSize(of: data) else { return .failure(ImportFailure(message: String(localized: "Can't read this image."))) }
        return .success(PendingImport(
            canvasId: canvasId, fileName: name, suggestedTitle: title, kind: .image, contentType: type.preferredMIMEType ?? "image/png", data: data,
            pixelSize: size, viewport: nil, capture: nil, containsScripts: false
        ))
    }

    func store(_ pending: PendingImport, target: Workspace.ImportTarget, in workspace: Workspace) throws -> Snapshot {
        try workspace.importArtifact(
            into: pending.canvasId,
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

    /// Reads at most `limit` bytes off the main actor, checking the size first.
    nonisolated static func readBounded(_ url: URL, limit: Int) async -> Result<Data, ImportFailure> {
        await Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let tooLarge = ImportFailure(Workspace.ImportError.tooLarge(limitMiB: limit / (1024 * 1024)))
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > limit { return .failure(tooLarge) }
            guard let handle = try? FileHandle(forReadingFrom: url) else { return .failure(ImportFailure.unreadable) }
            defer { try? handle.close() }
            guard let data = try? handle.read(upToCount: limit + 1) else { return .failure(ImportFailure.unreadable) }
            return data.count > limit ? .failure(tooLarge) : .success(data)
        }.value
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
