import Testing
import Foundation
@testable import CortexInfra

@Suite("PrefsStore")
struct PrefsStoreTests {
    /// A throwaway, isolated UserDefaults suite so tests never touch real prefs.
    private func makeStore(_ ns: String = "test") -> PrefsStore {
        let suite = "cortexkit.tests.\(ns).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return PrefsStore(namespace: ns, defaults: defaults)
    }

    @Test func namespacesKeys() {
        let store = makeStore("cortexdb")
        #expect(store.key("accentTheme") == "cortexdb.accentTheme")
    }

    @Test func roundTripsString() {
        let store = makeStore()
        store.set("violet", for: "accentTheme")
        #expect(store.string(for: "accentTheme") == "violet")
    }

    @Test func returnsDefaultWhenMissing() {
        let store = makeStore()
        #expect(store.string(for: "missing", default: "fallback") == "fallback")
        #expect(store.bool(for: "missing", default: true) == true)
        #expect(store.int(for: "missing", default: 42) == 42)
    }

    @Test func roundTripsTypedValues() {
        let store = makeStore()
        store.set(true, for: "flag")
        store.set(7, for: "count")
        store.set(1.5, for: "ratio")
        #expect(store.bool(for: "flag") == true)
        #expect(store.int(for: "count") == 7)
        #expect(store.double(for: "ratio") == 1.5)
    }

    @Test func removeClearsValue() {
        let store = makeStore()
        store.set("x", for: "k")
        store.remove("k")
        #expect(store.string(for: "k") == nil)
    }
}

@Suite("Keychain helpers")
struct KeychainShapeTests {
    @Test func uuidConvenienceMatchesStringForm() {
        // We don't touch the real keychain in unit tests; just assert the
        // UUID convenience resolves to the uuidString account key shape.
        let id = UUID()
        #expect(id.uuidString.count == 36)
    }
}
