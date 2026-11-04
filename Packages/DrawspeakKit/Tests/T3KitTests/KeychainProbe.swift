import DrawspeakCore
import Foundation

/// Whether this test process can write to the Keychain.
enum KeychainProbe {
    static let isAvailable: Bool = {
        let store = KeychainStore(service: "com.wydrox.drawspeak.tests.probe")
        defer { store.remove("probe") }
        return store.set("1", for: "probe")
    }()
}
