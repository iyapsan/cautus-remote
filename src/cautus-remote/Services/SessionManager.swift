import Foundation

/// Manages active remote sessions.
///
/// Coordinates between the SSH engine, Keychain, and workspace state.
/// Publishes session state changes for UI consumption.
///
/// `@MainActor` isolated to share the same domain as `AppState`
/// and `ConnectionService`, avoiding data races with non-Sendable model objects.
@MainActor
@Observable
final class SessionManager {
    /// Active sessions keyed by session ID
    private(set) var sessions: [UUID: any RemoteSession] = [:]

    /// The protocol engine (SSH in v1)
    private let engine: any RemoteProtocol

    /// Keychain for credential retrieval
    private let keychainService: KeychainService

    init(engine: any RemoteProtocol, keychainService: KeychainService = KeychainService()) {
        self.engine = engine
        self.keychainService = keychainService
    }

    // MARK: - Session Lifecycle

    /// Open a new session for a connection.
    ///
    /// - Parameter connection: The connection to open
    /// - Returns: The new session's UUID
    func open(connection: Connection) async throws -> UUID {
        // Retrieve credential from Keychain
        let credential: Credential
        switch connection.authMethod {
        case .password:
            guard let password = try keychainService.retrievePassword(for: connection.id) else {
                throw SessionError(code: .authFailed, message: "No password stored for this connection")
            }
            credential = .password(password)
        case .publicKey:
            guard let keyPath = connection.sshKeyPath else {
                throw SessionError(code: .keyNotFound, message: "No SSH key path configured")
            }
            let passphrase = try keychainService.retrievePassphrase(for: connection.id)
            credential = .privateKey(path: keyPath, passphrase: passphrase)
        }

        // Connect via the protocol engine
        let session = try await engine.connect(to: connection, credential: credential)
        sessions[session.id] = session

        return session.id
    }

    /// Close a session by ID.
    func close(sessionId: UUID) async {
        guard let session = sessions[sessionId] else { return }
        await session.close()
        sessions.removeValue(forKey: sessionId)
    }

    /// Reconnect a failed or disconnected session.
    func reconnect(sessionId: UUID) async throws {
        guard let session = sessions[sessionId] else { return }
        try await session.reconnect()
    }

    /// Get current state for a session.
    func state(for sessionId: UUID) -> SessionState {
        sessions[sessionId]?.state ?? .disconnected
    }

    /// Close all sessions (app shutdown).
    func closeAll() async {
        for sessionId in sessions.keys {
            await close(sessionId: sessionId)
        }
    }
}
