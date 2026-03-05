import Foundation
import CautusRDP

/// Manages active remote sessions.
///
/// Coordinates between the RDP engine, Keychain, and workspace state.
/// Publishes session state changes for UI consumption.
///
/// `@MainActor` isolated to share the same domain as `AppState`
/// and `ConnectionService`, avoiding data races with non-Sendable model objects.
@MainActor
@Observable
final class SessionManager {
    /// Active sessions keyed by session ID
    private(set) var sessions: [UUID: RDPSession] = [:]

    /// The protocol engine
    private let engine: RDPClient

    /// Keychain for credential retrieval
    private let keychainService: KeychainService

    init(engine: RDPClient = RDPClient(), keychainService: KeychainService = KeychainService()) {
        self.engine = engine
        self.keychainService = keychainService
    }

    // MARK: - Session Lifecycle

    /// Open a new session for a connection.
    ///
    /// - Parameter connection: The connection to open
    /// - Returns: The new session's UUID
    func open(connection: Connection) async throws -> UUID {
        // Prevent launching duplicates if a session is already active or connecting.
        // We reuse the connection.id as the session.id key in our architecture.
        if let existingSession = sessions[connection.id] {
            switch existingSession.state {
            case .connected, .connecting, .reconnecting(_, _):
                print("[SessionManager] Session for \(connection.id) already active/connecting. Deduplicating.")
                return connection.id
            case .idle, .disconnected:
                // Safely proceed to spawn a new one
                break
            }
        }

        // Retrieve credential from Keychain
        let password = try keychainService.retrievePassword(for: connection.id) ?? ""
        print("[SessionManager] Connecting to \(connection.host) with user \(connection.username). Password length: \(password.count)")

        // Resolve effective settings: Global → Folder chain → Connection overrides.
        // effectiveRDPConfig() decodes JSON blobs — fine here (connect time, not hot list path).
        // TODO: Replace .global with AppSettings.shared.rdpDefaults once Settings panel exists.
        let eff = connection.effectiveRDPConfig(global: .global)
        print("[SessionManager] effectiveConfig: \(eff)")

        // Map data model into strictly isolated configuration
        let config = RDPConfig(
            host: connection.host,
            port: eff.port,
            user: connection.username,
            pass: password,
            gwHost: connection.gatewayUrl,
            gwUser: connection.gatewayUsername,
            gwPass: try? keychainService.retrievePassword(for: connection.id),
            gwDomain: nil,
            gwMode: eff.gatewayMode.rawValue,
            gwBypassLocal: eff.gatewayBypassLocal,
            gwUseSameCreds: nil,
            ignoreCert: connection.ignoreCertificateErrors
        )

        // Connect via the protocol engine
        let session = try await engine.connect(config: config)
        
        // We use connection.id as the session key so 1 connection = 1 active session
        sessions[connection.id] = session

        return connection.id
    }

    /// Close a session by ID.
    func close(sessionId: UUID) async {
        guard let session = sessions[sessionId] else { return }
        session.disconnect()
        sessions.removeValue(forKey: sessionId)
    }

    /// Reconnect a failed or disconnected session.
    func reconnect(sessionId: UUID) async throws {
        guard let session = sessions[sessionId] else { return }
        session.disconnect()
        try await session.connect()
    }

    /// Get current state for a session.
    func state(for sessionId: UUID) -> RDPConnectionState {
        sessions[sessionId]?.state ?? .disconnected(nil)
    }

    /// Close all sessions (app shutdown).
    func closeAll() async {
        for sessionId in sessions.keys {
            await close(sessionId: sessionId)
        }
    }
}
