import Foundation

/// The identity of a T3 host: scheme, host and effective port. Paths and a
/// trailing slash are ignored, so `https://mac.ts.net/` equals `https://mac.ts.net:443`.
public enum HostIdentity {
    public static func key(_ url: URL) -> String {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let scheme = (components?.scheme ?? url.scheme ?? "").lowercased()
        var host = (components?.host ?? url.host() ?? "").lowercased()
        if host.hasSuffix(".") { host.removeLast() }
        let port = components?.port ?? defaultPort(for: scheme)
        return "\(scheme)://\(host):\(port.map(String.init) ?? "")"
    }

    public static func matches(_ lhs: URL, _ rhs: URL) -> Bool {
        key(lhs) == key(rhs)
    }

    /// Host name for messages, with a port only when it is not the default one.
    public static func displayName(_ url: URL) -> String {
        guard let host = url.host(), !host.isEmpty else { return url.absoluteString }
        let scheme = url.scheme?.lowercased() ?? ""
        if let port = url.port, port != defaultPort(for: scheme) { return "\(host):\(port)" }
        return host
    }

    private static func defaultPort(for scheme: String) -> Int? {
        switch scheme {
        case "https": 443
        case "http": 80
        default: nil
        }
    }
}

public extension ThreadBinding {
    /// Same host (see `HostIdentity`) and same thread id.
    func isSameRecipient(as other: ThreadBinding) -> Bool {
        threadId == other.threadId && HostIdentity.matches(hostURL, other.hostURL)
    }
}
