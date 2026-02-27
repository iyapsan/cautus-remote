import Foundation
import SwiftData

/// SSH connection configuration — persisted via SwiftData.
@Model
final class Connection {
    // MARK: - Identity

    @Attribute(.unique)
    var id: UUID

    var name: String
    var host: String
    var port: Int
    var username: String

    // MARK: - Authentication

    /// Stored as raw string for SwiftData compatibility
    var authMethodRaw: String

    /// Filesystem path to SSH private key (when using public key auth)
    var sshKeyPath: String?

    /// Reference to another Connection used as a jump/proxy host
    var jumpHostId: UUID?

    // MARK: - Organization

    var isFavorite: Bool
    var folder: Folder?

    @Relationship(inverse: \Tag.connections)
    var tags: [Tag]

    // MARK: - Advanced Settings

    /// Keepalive interval in seconds (default 60)
    var keepaliveInterval: Int

    /// Connection timeout in seconds (default 30)
    var connectionTimeout: Int

    /// Terminal font size override (nil = use default)
    var terminalFontSize: Int?

    /// Terminal scrollback buffer size (default 10000)
    var scrollbackLines: Int

    /// Environment variables to set on the remote session
    var environmentVarsData: Data?

    // MARK: - Timestamps

    var lastConnectedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties

    /// Type-safe access to auth method
    var authMethod: AuthMethod {
        get { AuthMethod(rawValue: authMethodRaw) ?? .password }
        set { authMethodRaw = newValue.rawValue }
    }

    /// Encode/decode environment vars as [String: String]
    var environmentVars: [String: String] {
        get {
            guard let data = environmentVarsData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            environmentVarsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Display string for the connection (user@host:port)
    var displayAddress: String {
        port == 22 ? "\(username)@\(host)" : "\(username)@\(host):\(port)"
    }

    // MARK: - Init

    init(
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authMethod: AuthMethod = .password,
        sshKeyPath: String? = nil,
        jumpHostId: UUID? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethodRaw = authMethod.rawValue
        self.sshKeyPath = sshKeyPath
        self.jumpHostId = jumpHostId
        self.isFavorite = false
        self.tags = []
        self.keepaliveInterval = 60
        self.connectionTimeout = 30
        self.scrollbackLines = 10000
        self.createdAt = .now
        self.updatedAt = .now
    }
}
