import Testing
@testable import VoiceKit

struct ElevenLabsKeyStoreTests {
    @Test func fixedKeyIsTrimmedAndEmptyMeansNoKey() {
        #expect(ElevenLabsKeyStore(fixedKey: "  test-key \n").key() == "test-key")
        #expect(ElevenLabsKeyStore(fixedKey: "   ").hasKey == false)
        #expect(ElevenLabsKeyStore(fixedKey: nil).hasKey == false)
        #expect(ElevenLabsKeyStore(fixedKey: "test-key").hasKey)
    }

    @Test func fixedStoreNeverWritesToTheKeychain() {
        let store = ElevenLabsKeyStore(fixedKey: nil)
        #expect(store.save("test-key") == false)
        #expect(store.hasKey == false)
    }

    @Test func rejectsEmptyKeyWithoutTouchingTheKeychain() {
        #expect(ElevenLabsKeyStore().save("  \n ") == false)
    }
}
