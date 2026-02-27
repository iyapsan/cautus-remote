import Foundation

/// Credential retrieved from Keychain — never persisted as plaintext.
enum Credential: Sendable {
    case password(String)
    case privateKey(path: String, passphrase: String?)
}
