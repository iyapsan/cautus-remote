import Foundation

/// Authentication method for a remote connection.
enum AuthMethod: String, Codable, CaseIterable, Sendable {
    case password
    case publicKey
}
