import XCTest
@testable import dazi

@MainActor
final class SecureTokenStoreTests: XCTestCase {
    func testStoreUpdateAndDeleteRoundTrip() {
        let account = "test-\(UUID().uuidString)"
        let store = SecureTokenStore.shared
        defer { store.set(nil, for: account) }
        store.set("first", for: account)
        XCTAssertEqual(store.string(for: account), "first")
        store.set("second", for: account)
        XCTAssertEqual(store.string(for: account), "second")
        store.set(nil, for: account)
        XCTAssertNil(store.string(for: account))
    }

    func testLegacyTokenMigratesAndIsRemovedFromDefaults() {
        let account = "test-\(UUID().uuidString)"
        let legacy = "legacy-\(UUID().uuidString)"
        let store = SecureTokenStore.shared
        defer {
            store.set(nil, for: account)
            UserDefaults.standard.removeObject(forKey: legacy)
        }
        UserDefaults.standard.set("legacy-value", forKey: legacy)
        XCTAssertEqual(store.string(for: account, migrating: legacy), "legacy-value")
        XCTAssertEqual(store.string(for: account), "legacy-value")
        XCTAssertNil(UserDefaults.standard.string(forKey: legacy))
    }

    func testKeychainValueWinsOverStaleLegacyToken() {
        let account = "test-\(UUID().uuidString)"
        let legacy = "legacy-\(UUID().uuidString)"
        let store = SecureTokenStore.shared
        defer {
            store.set(nil, for: account)
            UserDefaults.standard.removeObject(forKey: legacy)
        }
        store.set("current", for: account)
        UserDefaults.standard.set("stale", forKey: legacy)
        XCTAssertEqual(store.string(for: account, migrating: legacy), "current")
        XCTAssertNil(UserDefaults.standard.object(forKey: legacy))
    }
}
