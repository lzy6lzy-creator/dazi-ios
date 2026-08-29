import Foundation
import Security

final class SecureTokenStore {
    static let shared = SecureTokenStore()

    private let service = "com.linke.dazi.auth"

    private init() {}

    func string(for account: String, migrating legacyDefaultsKey: String? = nil) -> String? {
        if let value = keychainString(for: account) {
            removeLegacyValue(for: legacyDefaultsKey)
            return value
        }

        guard let legacyDefaultsKey,
              let legacyValue = UserDefaults.standard.string(forKey: legacyDefaultsKey),
              !legacyValue.isEmpty else {
            return nil
        }

        guard store(legacyValue, for: account) else {
            return legacyValue
        }
        UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        return legacyValue
    }

    func set(_ value: String?, for account: String, removingLegacyDefaultsKey legacyDefaultsKey: String? = nil) {
        guard let value, !value.isEmpty else {
            delete(account: account)
            removeLegacyValue(for: legacyDefaultsKey)
            return
        }

        if store(value, for: account) {
            removeLegacyValue(for: legacyDefaultsKey)
        }
    }

    private func store(_ value: String, for account: String) -> Bool {
        let data = Data(value.utf8)
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemUpdate(match as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = match
            attributes.forEach { item[$0.key] = $0.value }
            return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    private func keychainString(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func removeLegacyValue(for key: String?) {
        guard let key else { return }
        UserDefaults.standard.removeObject(forKey: key)
    }
}
