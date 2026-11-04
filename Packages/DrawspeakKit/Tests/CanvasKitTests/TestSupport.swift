import CoreGraphics
import DrawspeakCore
import Foundation
import Testing

let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)

let regionShape = AnnotationShape.region(NRect(x: 0.1, y: 0.1, width: 0.3, height: 0.2))

/// A workspace backed by a fresh temp directory with one project and one canvas.
@MainActor
func makeWorkspace(thread: ThreadBinding? = nil) -> Workspace {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let project = Project(name: "Test", createdAt: fixedDate)
    let canvas = ReviewCanvas(projectId: project.id, title: "Review", thread: thread, createdAt: fixedDate, updatedAt: fixedDate)
    let document = LibraryDocument(projects: [project], canvases: [canvas], lastCanvasId: canvas.id)
    let workspace = Workspace(
        document: document,
        blobs: BlobStore(root: root.appending(path: "blobs")),
        store: LibraryStore(fileURL: root.appending(path: "library.json"))
    )
    workspace.now = { fixedDate }
    return workspace
}

/// Imports a distinct 100x200 image as a new screen (Now) with the given snapshot id.
@MainActor
@discardableResult
func addScreen(_ ws: Workspace, id: String, title: String) throws -> Snapshot {
    try ws.importArtifact(
        data: Data("screen-bytes-\(id)".utf8),
        kind: .image,
        contentType: "image/png",
        fileName: "\(id).png",
        pixelSize: (width: 100, height: 200),
        target: .newScreen(title: title),
        snapshotId: id
    )
}

/// Imports a distinct 100x200 image as the next iteration of a proposal.
@MainActor
@discardableResult
func addProposal(_ ws: Workspace, screenId: String, proposal: String, id: String) throws -> Snapshot {
    try ws.importArtifact(
        data: Data("proposal-bytes-\(id)".utf8),
        kind: .image,
        contentType: "image/png",
        fileName: "\(id).png",
        pixelSize: (width: 100, height: 200),
        target: .proposal(screenId: screenId, proposalId: proposal),
        snapshotId: id
    )
}

/// Imports an HTML snapshot (390x844) as the next iteration of a proposal.
@MainActor
@discardableResult
func addHTMLProposal(_ ws: Workspace, screenId: String, proposal: String, id: String) throws -> Snapshot {
    try ws.importArtifact(
        data: Data("<html><body><button>Pay</button></body></html>\(id)".utf8),
        kind: .html,
        contentType: "text/html",
        fileName: "\(id).html",
        pixelSize: (width: 390, height: 844),
        viewport: Viewport(width: 390, height: 844),
        target: .proposal(screenId: screenId, proposalId: proposal),
        snapshotId: id
    )
}

/// Canvas with screen "s1" (Now + Proposal A + Proposal B) and screen "s2" (Now).
@MainActor
struct TwoScreenFixture {
    let ws: Workspace
    let s1: String
    let s2: String
    let proposalA: Snapshot
    let proposalB: Snapshot

    var canvas: ReviewCanvas { ws.currentCanvas! }

    init() throws {
        ws = makeWorkspace()
        let now1 = try addScreen(ws, id: "s1-now", title: "Checkout")
        s1 = now1.screenId
        proposalA = try addProposal(ws, screenId: s1, proposal: "A", id: "s1-a")
        proposalB = try addProposal(ws, screenId: s1, proposal: "B", id: "s1-b")
        s2 = try addScreen(ws, id: "s2-now", title: "Cart").screenId
    }
}

func approx(_ a: CGPoint, _ b: CGPoint, tolerance: CGFloat = 1e-9) -> Bool {
    abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance
}

/// `count` points evenly interpolated from `a` to `b`, both included.
func line(from a: CGPoint, to b: CGPoint, count: Int = 20) -> [CGPoint] {
    (0..<count).map { index in
        let t = CGFloat(index) / CGFloat(count - 1)
        return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}
