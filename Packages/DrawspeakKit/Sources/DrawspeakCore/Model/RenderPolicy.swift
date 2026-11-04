import Foundation

/// How an HTML snapshot is rendered. The policy is part of the immutable version.
public enum RenderPolicy: String, Codable, Hashable, Sendable {
    /// Scripts, navigation and network are blocked; HTML and CSS only.
    case staticNoScript = "static-no-script"
    /// Page scripts run against fixture data in an isolated, offline web view.
    case isolatedScripted = "isolated-scripted-offline"
}
