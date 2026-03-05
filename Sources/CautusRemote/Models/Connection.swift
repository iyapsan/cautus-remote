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

    // MARK: - Advanced RDP Settings

    var gatewayUrl: String?
    var gatewayUsername: String?
    var ignoreCertificateErrors: Bool

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

    // MARK: - RDP Profile Overrides (stored as JSON blob to avoid SwiftData migrations)

    /// Raw JSON blob. Decode only at connect time via `rdpOverrides`.
    var rdpOverridesData: Data?

    /// Connection-level RDP overrides. All fields are optional; nil = inherit from folder chain.
    /// JSON decoded here — call only at connect time, not in list rendering hot paths.
    var rdpOverrides: RDPOverrides {
        get { rdpOverridesData.flatMap { try? JSONDecoder().decode(RDPOverrides.self, from: $0) } ?? RDPOverrides() }
        set { rdpOverridesData = try? JSONEncoder().encode(newValue) }
    }

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

    // MARK: - Effective RDP Configuration

    /// Build the folder chain from leaf to root, then reverse (root-first).
    /// Cycle-guarded: stop if a folder id is seen twice.
    private func buildFolderChain() -> [Folder] {
        return CautusRemote.buildFolderChain(from: folder)
    }

    /// Resolve the effective RDP configuration for this connection.
    ///
    /// - Parameter global: App-wide baseline defaults.
    ///   Pass `AppSettings.rdpDefaults` in production; use `.global` in tests / early v1.
    /// - Note: Decodes JSON blobs internally. Call only at connect time — NOT during list rendering.
    func effectiveRDPConfig(global: RDPProfileDefaults = .global) -> RDPProfileDefaults {
        let chain = buildFolderChain()
        return resolveRDPConfig(connection: self, folderChain: chain, global: global)
    }

    // MARK: - Init

    init(
        name: String,
        host: String,
        port: Int = 3389,
        username: String,
        authMethod: AuthMethod = .password,
        sshKeyPath: String? = nil,
        jumpHostId: UUID? = nil,
        gatewayUrl: String? = nil,
        gatewayUsername: String? = nil,
        ignoreCertificateErrors: Bool = false
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
        self.gatewayUrl = gatewayUrl
        self.gatewayUsername = gatewayUsername
        self.ignoreCertificateErrors = ignoreCertificateErrors
    }
}
