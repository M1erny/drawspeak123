import Foundation

public enum T3ConnectionState: Equatable, Sendable {
    case notPaired, connecting, connected(URL), failed(String), expired
}
