import DrawspeakCore
import Foundation
import HTMLKit
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// Reads imported files and stores them as immutable snapshots.
@MainActor
struct ImportCoordinator {
    static let allowedTypes: [UTType] = [.html, .pdf, .png, .jpeg, .webP, .heic]

    func read(_ url: URL, canvasId: UUID, progress: @escaping @MainActor @Sendable (Int, Int) -> Void) async -> Result<[PendingImport], ImportFailure> {
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
                return .success([PendingImport(
                    canvasId: canvasId, fileName: name, suggestedTitle: info.title ?? title, kind: .html, contentType: "text/html", data: data,
                    pixelSize: (capture.pixelWidth, capture.pixelHeight), viewport: info.suggestedViewport,
                    capture: capture.pngData, containsScripts: info.containsScripts
                )])
            } catch {
                return .failure(ImportFailure(message: String(localized: "Can't render this HTML.")))
            }
        }
        if type.conforms(to: .pdf) {
            return await PDFImport.render(data, canvasId: canvasId, title: title, progress: progress)
        }
        if type.conforms(to: .heic) {
            return await Self.readPhoto(data, canvasId: canvasId, title: title)
                .map { [$0] }
        }
        guard Self.allowedTypes.contains(where: { type.conforms(to: $0) }) else {
            return .failure(ImportFailure(Workspace.ImportError.unsupportedType))
        }
        guard let size = Self.pixelSize(of: data) else { return .failure(ImportFailure(message: String(localized: "Can't read this image."))) }
        return .success([PendingImport(
            canvasId: canvasId, fileName: name, suggestedTitle: title, kind: .image, contentType: type.preferredMIMEType ?? "image/png", data: data,
            pixelSize: size, viewport: nil, capture: nil, containsScripts: false
        )])
    }

    nonisolated static func readPhoto(_ data: Data, canvasId: UUID, title: String = "Photo") async -> Result<PendingImport, ImportFailure> {
        let limit = await Workspace.maxImageBytes
        return await Task.detached(priority: .userInitiated) {
            guard let encoded = ImageImport.photo(data), let size = pixelSize(of: encoded) else {
                return .failure(ImportFailure(message: String(localized: "Can't read this photo.")))
            }
            guard encoded.count <= limit else {
                return .failure(ImportFailure(Workspace.ImportError.tooLarge(limitMiB: limit / (1024 * 1024))))
            }
            return .success(PendingImport(
                canvasId: canvasId, fileName: "\(title).jpg", suggestedTitle: title,
                kind: .image, contentType: "image/jpeg", data: encoded, pixelSize: size,
                viewport: nil, capture: nil, containsScripts: false
            ))
        }.value
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

    nonisolated static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { return nil }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        return orientation >= 5 ? (height, width) : (width, height)
    }
}

nonisolated enum ImageImport {
    /// ImageIO applies EXIF orientation to pixels before discarding source metadata.
    static func photo(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(width, height)
              ] as CFDictionary) else { return nil }
        return encode(image, as: .jpeg)
    }

    /// PDFKit's platform image scale can vary; persist exactly the requested pixel size.
    static func resized(_ image: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        if image.width == width, image.height == height { return image }
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    static func encode(_ image: CGImage, as type: UTType) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else { return nil }
        let options: [CFString: Any] = type == .jpeg ? [kCGImageDestinationLossyCompressionQuality: 0.9] : [:]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

nonisolated enum PDFImport {
    static func render(
        _ data: Data, canvasId: UUID, title: String,
        progress: @escaping @MainActor @Sendable (Int, Int) -> Void
    ) async -> Result<[PendingImport], ImportFailure> {
        let limit = await Workspace.maxImageBytes
        return await Task.detached(priority: .userInitiated) {
            guard let document = PDFDocument(data: data), !document.isLocked, document.pageCount > 0 else {
                return .failure(ImportFailure(message: String(localized: "Can't read this PDF.")))
            }
            guard document.pageCount <= 20 else {
                return .failure(ImportFailure(message: String(localized: "Choose a PDF with up to 20 pages.")))
            }
            var pages: [PendingImport] = []
            for index in 0..<document.pageCount {
                await progress(index + 1, document.pageCount)
                let pending: PendingImport? = autoreleasepool {
                    guard let page = document.page(at: index) else { return nil }
                    let bounds = page.bounds(for: .cropBox)
                    let rotated = page.rotation % 180 != 0
                    let width = rotated ? bounds.height : bounds.width
                    let height = rotated ? bounds.width : bounds.height
                    guard width.isFinite, height.isFinite, width > 0, height > 0 else { return nil }
                    let scale = 2048 / max(width, height)
                    let size = CGSize(width: max(1, (width * scale).rounded()), height: max(1, (height * scale).rounded()))
                    guard let thumbnail = page.thumbnail(of: size, for: .cropBox).cgImage,
                          let image = ImageImport.resized(thumbnail, to: size),
                          let encoded = ImageImport.encode(image, as: .png),
                          let pixels = ImportCoordinator.pixelSize(of: encoded) else { return nil }
                    let pageTitle = document.pageCount == 1 ? title : "\(title) – Page \(index + 1)"
                    return PendingImport(
                        canvasId: canvasId, fileName: "\(pageTitle).png", suggestedTitle: pageTitle,
                        kind: .image, contentType: "image/png", data: encoded, pixelSize: pixels,
                        viewport: nil, capture: nil, containsScripts: false
                    )
                }
                guard let pending else {
                    return .failure(ImportFailure(message: String(localized: "Can't render this PDF.")))
                }
                guard pending.data.count <= limit else {
                    return .failure(ImportFailure(Workspace.ImportError.tooLarge(limitMiB: limit / (1024 * 1024))))
                }
                pages.append(pending)
            }
            return .success(pages)
        }.value
    }
}
