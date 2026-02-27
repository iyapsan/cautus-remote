import Foundation
import Security

/// Thin wrapper around macOS Keychain Services API.
///
/// All credentials are stored per-connection using the connection's UUID
/// as the account identifier. No third-party dependencies.
struct KeychainService: Sendable {
    private let serviceName = "com.cautus.remote"

    // MARK: - Password

    /// Store a password for a connection.
    func storePassword(_ password: String, for connectionId: UUID) throws {
        let data = Data(password.utf8)
        try store(data: data, account: passwordAccount(connectionId))
    }

    /// Retrieve the stored password for a connection.
    func retrievePassword(for connectionId: UUID) throws -> String? {
        guard let data = try retrieve(account: passwordAccount(connectionId)) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Delete the stored password for a connection.
    func deletePassword(for connectionId: UUID) throws {
        try delete(account: passwordAccount(connectionId))
    }

    // MARK: - Key Passphrase

    /// Store a private key passphrase for a connection.
    func storePassphrase(_ passphrase: String, for connectionId: UUID) throws {
        let data = Data(passphrase.utf8)
        try store(data: data, account: passphraseAccount(connectionId))
    }

    /// Retrieve the stored passphrase for a connection.
    func retrievePassphrase(for connectionId: UUID) throws -> String? {
        guard let data = try retrieve(account: passphraseAccount(connectionId)) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Cleanup

    /// Delete all credentials (password + passphrase) for a connection.
    func deleteAll(for connectionId: UUID) throws {
        try? deletePassword(for: connectionId)
        try? delete(account: passphraseAccount(connectionId))
    }

    // MARK: - Private Helpers

    private func passwordAccount(_ id: UUID) -> String {
        "password-\(id.uuidString)"
    }

    private func passphraseAccount(_ id: UUID) -> String {
        "passphrase-\(id.uuidString)"
    }

    private func store(data: Data, account: String) throws {
        // Delete any existing item first
        try? delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    private func retrieve(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }

    private func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}

// MARK: - Errors

enum KeychainError: Error, LocalizedError {
    case unhandledError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandledError(let status):
            if let message = SecCopyErrorMessageString(status, nil) {
                return message as String
            }
            return "Keychain error: \(status)"
        }
    }
}
