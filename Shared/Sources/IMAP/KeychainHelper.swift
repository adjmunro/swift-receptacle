import Foundation
import Security

// MARK: - KeychainHelper

/// Thread-safe Keychain wrapper.
///
/// All credentials (IMAP passwords, OAuth tokens) are stored here.
/// Never use UserDefaults or on-disk files for secrets.
///
/// Key structure:
///   service = "com.user.receptacle" (or "com.user.receptacle.debug")
///   account = "<accountId>.<credentialKind>"
///
/// Example:
///   account = "icloud-adam@icloud.com.password"
///   account = "gmail-adam@gmail.com.oauth-google"
public enum KeychainHelper {

    // MARK: - Constants

    /// Service name — matches the app bundle ID prefix.
    /// Debug builds automatically use a separate service via the DEBUG suffix.
    #if DEBUG
    private static let service = "com.user.receptacle.debug"
    #else
    private static let service = "com.user.receptacle"
    #endif

    // MARK: - CRUD

    /// Saves (or updates) a string credential in the Keychain.
    public static func save(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Try update first
        let updateQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let updateAttributes: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary,
                                        updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist — add it
            let addQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecValueData: data,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            ]
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    /// Reads a credential from the Keychain. Returns nil if not found.
    public static func read(account: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.decodingFailed
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Deletes a credential from the Keychain. No-ops silently if not found.
    public static func delete(account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Convenience account key builders

    /// Keychain account key for an IMAP app-specific password.
    public static func passwordKey(accountId: String) -> String {
        "\(accountId).password"
    }

    /// Keychain account key for an OAuth2 access token.
    public static func oauthTokenKey(accountId: String, provider: String) -> String {
        "\(accountId).oauth-\(provider)"
    }

    /// Keychain account key for an OAuth2 refresh token.
    public static func oauthRefreshKey(accountId: String, provider: String) -> String {
        "\(accountId).oauth-refresh-\(provider)"
    }
}

// MARK: - KeychainError

public enum KeychainError: Error, Sendable {
    case encodingFailed
    case decodingFailed
    case unexpectedStatus(OSStatus)

    public var localizedDescription: String {
        switch self {
        case .encodingFailed: return "Failed to encode credential as UTF-8"
        case .decodingFailed: return "Failed to decode credential from Keychain data"
        case .unexpectedStatus(let code): return "Keychain error \(code)"
        }
    }
}
