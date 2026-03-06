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

    // MARK: - RDP Patch (stored as JSON blob; decode only at connect time or in editors)

    /// Raw JSON blob for this connection's RDP patch.
    /// Renamed from `rdpOverridesData` per the formal spec.
    /// `nil` here semantically means "no overrides at all" — distinct from an empty patch.
    var rdpPatchData: Data?

    /// Connection-level RDP patch. All fields optional — nil fields inherit from the folder chain.
    /// Persistence stores nil when no overrides exist (not an empty struct).
    /// The UI convenience getter returns `RDPPatch()` so callers don’t need to unwrap.
    var rdpPatch: RDPPatch? {
        get { rdpPatchData.flatMap { try? JSONDecoder().decode(RDPPatch.self, from: $0) } }
        set {
            // Store nil when patch is empty — preserves semantic distinction between
            // "no overrides" (nil) and "explicit empty override object".
            if let patch = newValue, !patch.isEmpty {
                rdpPatchData = try? JSONEncoder().encode(patch)
            } else {
                rdpPatchData = nil
            }
        }
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
        port == 3389 ? "\(username)@\(host)" : "\(username)@\(host):\(port)"
    }

    // MARK: - Effective RDP Configuration

    /// Resolve the effective RDP configuration for this connection.
    ///
    /// Uses the canonical `buildFolderChain(for:)` helper — NOT a local duplicate.
    /// Decodes JSON blobs internally. Call only at connect time — NOT during list rendering.
    ///
    /// - Parameter global: App-wide baseline. Use `AppSettings.rdpDefaults` in production;
    ///   `.global` in tests / early v1.
    func effectiveRDPConfig(global: RDPResolvedConfig = .global) -> RDPResolvedConfig {
        let chain = buildFolderChain(for: folder)
        return resolveRDPConfig(
            global: global,
            folderChain: chain,
            connectionPatch: rdpPatch
        )
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
