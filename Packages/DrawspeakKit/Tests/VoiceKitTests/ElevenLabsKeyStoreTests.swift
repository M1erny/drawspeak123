import Testing
@testable import VoiceKit

struct ElevenLabsKeyStoreTests {
    @Test func fixedKeyIsTrimmedAndEmptyMeansNoKey() {
        #expect(ElevenLabsKeyStore(fixedKey: "  test-key \n").key() == "test-key")
        #expect(ElevenLabsKeyStore(fixedKey: "   ").hasKey == false)
        #expect(ElevenLabsKeyStore(fixedKey: nil).hasKey == false)
        #expect(ElevenLabsKeyStore(fixedKey: "test-key").hasKey)
    }

    @Test func readsTheBuiltInKeyFromTheInfoDictionary() {
        let store = ElevenLabsKeyStore(infoDictionary: ["DSElevenLabsAPIKey": " built-in-key ", "Other": "x"])
        #expect(store.hasKey)
        #expect(store.key() == "built-in-key")
    }

    @Test(arguments: [
        ["DSElevenLabsAPIKey": "$(ELEVENLABS_API_KEY)"],
        ["DSElevenLabsAPIKey": ""],
        ["DSElevenLabsAPIKey": "  \n"],
        ["DSElevenLabsAPIKey": 42],
        [:],
    ] as [[String: any Sendable]])
    func missingOrUnexpandedKeyMeansNoKey(info: [String: any Sendable]) {
        let store = ElevenLabsKeyStore(infoDictionary: info)
        #expect(store.hasKey == false)
        #expect(store.key() == nil)
    }
}
