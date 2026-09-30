import Foundation
import Security

/// Keeps the GitHub token in the user's Keychain. It is never written to the JSON data file,
/// to the preferences, or to the log.
enum TokenStore {
    private static let service = "local.kalendario.app"
    private static let account = "github-token"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    /// The Keychain token, or `GITHUB_TOKEN` from the environment as a developer fallback.
    static func token() -> String? {
        if let stored = keychainToken() { return stored }
        let fromEnvironment = ProcessInfo.processInfo.environment["GITHUB_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (fromEnvironment?.isEmpty == false) ? fromEnvironment : nil
    }

    static var hasStoredToken: Bool {
        // Attributes only: this never decrypts the secret, so macOS does not ask for the
        // login-keychain password just to draw the import sheet.
        var query = baseQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true
        var item: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess
    }

    @discardableResult
    static func save(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return delete() }
        let data = Data(trimmed.utf8)

        var lookup = baseQuery
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        lookup[kSecReturnData as String] = true

        if SecItemCopyMatching(lookup as CFDictionary, nil) == errSecSuccess {
            let updates: [String: Any] = [kSecValueData as String: data]
            return SecItemUpdate(baseQuery as CFDictionary, updates as CFDictionary) == errSecSuccess
        }

        var insertion = baseQuery
        insertion[kSecValueData as String] = data
        insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(insertion as CFDictionary, nil)
        if status != errSecSuccess {
            NSLog("Kalendario: could not store the GitHub token in the Keychain (status \(status))")
        }
        return status == errSecSuccess
    }

    @discardableResult
    static func delete() -> Bool {
        let status = SecItemDelete(baseQuery as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func keychainToken() -> String? {
        var query = baseQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }
}