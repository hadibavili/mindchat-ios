import Foundation
import Security

// MARK: - Keychain Manager

final class KeychainManager: Sendable {

    static let shared = KeychainManager()

    private enum Key {
        static let jwt          = "mc_jwt"
        static let refreshToken = "mc_refresh_token"
    }

    private init() {}

    // MARK: JWT

    var accessToken: String? {
        get { read(key: Key.jwt) }
        set {
            if let value = newValue { save(key: Key.jwt, value: value) }
            else { delete(key: Key.jwt) }
        }
    }

    var refreshToken: String? {
        get { read(key: Key.refreshToken) }
        set {
            if let value = newValue { save(key: Key.refreshToken, value: value) }
            else { delete(key: Key.refreshToken) }
        }
    }

    var isAuthenticated: Bool {
        accessToken != nil
    }

    func save(tokens: (access: String, refresh: String)) {
        accessToken  = tokens.access
        refreshToken = tokens.refresh
    }

    func clearAll() {
        delete(key: Key.jwt)
        delete(key: Key.refreshToken)
    }

    // MARK: - Private CRUD

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
