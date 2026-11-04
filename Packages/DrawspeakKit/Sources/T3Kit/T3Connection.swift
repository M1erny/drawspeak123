import Foundation
import Observation

@MainActor @Observable public final class T3Connection {
    public static let defaultHost = URL(string: "https://rafals-mac-mini.tail71fdd0.ts.net")!
    public private(set) var state: T3ConnectionState = .notPaired
    public private(set) var credentials: T3Credentials?
    public var compatibilityWarning: String? {
        guard let version = credentials?.endpoint?.serverVersion, version != "0.1.7-nightly.20261101.4016" else { return nil }
        return "This T3 Code version (\(version)) differs from the version checked with Drawspeak."
    }
    public var hostURL: URL
    public private(set) var threadService: T3ThreadService?
    private let store: T3CredentialStore
    private let session: URLSession
    private var generation = UUID()
    public init(hostURL: URL = T3Connection.defaultHost, session: URLSession? = nil, store: T3CredentialStore = T3CredentialStore()) {
        self.hostURL = hostURL; self.store = store
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false; configuration.timeoutIntervalForRequest = 60
        self.session = session ?? URLSession(configuration: configuration)
    }
    public func pair(host: URL, code: String, accessLevel: String = "full-access") async {
        generation = UUID(); let operation = generation; state = .connecting
        let previousClient = threadService?.client; threadService = nil
        await previousClient?.close()
        do {
            let credential = try await T3Pairing.pair(host: host, code: code, accessLevel: accessLevel, session: session)
            guard generation == operation else { return }
            guard store.save(credential) else { state = .failed("Could not save the credential in Keychain."); return }
            UserDefaults.standard.set(credential.hostURL.absoluteString, forKey: "drawspeak.t3.host")
            await connect(credential, generation: operation)
        } catch { if generation == operation { state = .failed(error.message) } }
    }
    public func restore() async {
        generation = UUID(); let operation = generation
        let previousClient = threadService?.client; threadService = nil; credentials = nil
        await previousClient?.close()
        if let saved = UserDefaults.standard.string(forKey: "drawspeak.t3.host"), let url = try? T3Pairing.normalizeHost(saved) { hostURL = url }
        guard let credential = store.load(host: hostURL) else { state = .notPaired; return }
        credentials = credential
        guard credential.expiresAt > Date() else { state = .expired; threadService = nil; return }
        state = .connecting; await connect(credential, generation: operation)
    }
    /// True only when an unexpired saved credential can be used without pairing again.
    public var canReconnect: Bool {
        guard let credentials, credentials.expiresAt > Date() else { return false }
        switch state {
        case .failed, .connected: return true
        case .notPaired, .connecting, .expired: return false
        }
    }
    public func reconnect() async {
        guard state != .connecting, state != .expired, let credential = credentials else { return }
        guard credential.expiresAt > Date() else { state = .expired; threadService = nil; return }
        generation = UUID(); let operation = generation
        state = .connecting
        let previousClient = threadService?.client; threadService = nil
        await previousClient?.close()
        guard generation == operation else { return }
        await connect(credential, generation: operation)
    }
    private func connect(_ credential: T3Credentials, generation operation: UUID) async {
        credentials = credential; hostURL = credential.hostURL
        let client = MCPClient(credentials: credential, session: session)
        do {
            try await client.initialize()
            guard generation == operation else { await client.close(); return }
            threadService = T3ThreadService(client: client); state = .connected(hostURL)
        } catch { if generation == operation { threadService = nil; if case .unauthorized = error { state = .expired } else { state = .failed(error.localizedDescription) } } }
    }
    public func disconnect() {
        generation = UUID()
        let client = threadService?.client
        store.remove(host: credentials?.hostURL ?? hostURL)
        credentials = nil; threadService = nil; state = .notPaired
        UserDefaults.standard.removeObject(forKey: "drawspeak.t3.host")
        Task { await client?.close() }
    }
}
