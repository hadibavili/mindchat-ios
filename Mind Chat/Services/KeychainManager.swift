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

    /// Decodes the JWT payload and returns the user claims it contains (no network needed).
    var jwtUserClaims: (id: String, email: String, name: String?, emailVerified: String?)? {
        guard let token = accessToken else { return nil }
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        // Base64url → Base64 padding
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        guard let id = json["id"] as? String ?? json["sub"] as? String,
              let email = json["email"] as? String
        else { return nil }

        let name = json["name"] as? String
        // emailVerified may be a date string, a bool, or absent
        let emailVerified: String?
        if let v = json["emailVerified"] as? String { emailVerified = v }
        else if let v = json["email_verified"] as? Bool { emailVerified = v ? "verified" : nil }
        else { emailVerified = nil }

        return (id: id, email: email, name: name?.isEmpty == true ? nil : name, emailVerified: emailVerified)
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
