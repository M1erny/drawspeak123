import Foundation

/// Paths of files an agent wrote in a thread's workspace on the Mac. Drawspeak only
/// downloads files inside that workspace: workspace-relative paths, or absolute paths
/// under the workspace root. Traversal (`..`), `~`, URLs and backslashes are rejected.
public enum WorkspaceFilePath {
    public static let maxLength = 1024

    /// Syntactic check without knowing the workspace root.
    public static func isAcceptable(_ path: String) -> Bool {
        guard !path.isEmpty, path.utf8.count <= maxLength, !path.contains("\0"), !path.contains("\\"),
              !path.hasPrefix("~"), !path.contains("://") else { return false }
        let segments = path.split(separator: "/", omittingEmptySubsequences: false)
        let body = path.hasPrefix("/") ? segments.dropFirst() : segments[...]
        return !body.isEmpty && body.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    /// The workspace-relative form of `path`, or nil when it is unsafe or outside `root`.
    public static func relative(_ path: String, root: String) -> String? {
        guard isAcceptable(path) else { return nil }
        guard path.hasPrefix("/") else { return path }
        var base = root
        while base.count > 1, base.hasSuffix("/") { base.removeLast() }
        guard base.hasPrefix("/"), isAcceptable(base) || base == "/" else { return nil }
        let prefix = base == "/" ? "/" : base + "/"
        guard path.hasPrefix(prefix) else { return nil }
        let rest = String(path.dropFirst(prefix.count))
        return isAcceptable(rest) && !rest.hasPrefix("/") ? rest : nil
    }

    /// `relative` resolved against the directory of `file` (both validated).
    public static func sibling(_ relative: String, of file: String) -> String? {
        guard isAcceptable(relative), !relative.hasPrefix("/"), isAcceptable(file) else { return nil }
        guard let slash = file.lastIndex(of: "/") else { return relative }
        let joined = String(file[...slash]) + relative
        return isAcceptable(joined) ? joined : nil
    }

    /// Lowercased extension without the dot.
    public static func fileExtension(_ path: String) -> String {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
        return name[name.index(after: dot)...].lowercased()
    }
}
