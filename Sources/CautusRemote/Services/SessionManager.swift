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
    func open(connection: Connection) -> UUID {
        // Prevent launching duplicates if a session is already active or connecting.
        if let existingSession = sessions[connection.id] {
            switch existingSession.state {
            case .connected, .connecting, .reconnecting(_, _):
                print("[SessionManager] Session for \(connection.id) already active/connecting. Deduplicating.")
                return connection.id
            case .idle, .disconnected:
                break
            }
        }

        // 1. Resolve configuration early.
        let eff = connection.effectiveRDPConfig(global: .global)
        let configTemplate = RDPConfig(
            host: connection.host,
            port: eff.port,
            user: connection.username,
            pass: "", // Empty to start, satisfied later.
            gwHost: connection.gatewayUrl,
            gwUser: connection.gatewayUsername,
            gwPass: nil,
            gwDomain: nil,
            gwMode: eff.gatewayMode.rawValue,
            gwBypassLocal: eff.gatewayBypassLocal,
            gwUseSameCreds: nil,
            ignoreCert: connection.ignoreCertificateErrors
        )

        // 2. Put a skeleton session in place immediately. This guarantees that when SwiftUI 
        // calls `openWindow` synchronously, the UI component (`WorkspaceView`) will find it immediately.
        let session = RDPSession(config: configTemplate)
        sessions[connection.id] = session

        let keychainSvc = self.keychainService
        let connectionId = connection.id

        // 3. Move the blocking SecurityAgent OS Keychain GUI prompt completely off the Main Thread.
        Task.detached {
            do {
                let password = try keychainSvc.retrievePassword(for: connectionId) ?? ""
                let gwPass = try? keychainSvc.retrievePassword(for: connectionId)

                let realConfig = RDPConfig(
                    host: configTemplate.host,
                    port: configTemplate.port,
                    user: configTemplate.user,
                    pass: password,
                    gwHost: configTemplate.gwHost,
                    gwUser: configTemplate.gwUser,
                    gwPass: gwPass,
                    gwDomain: configTemplate.gwDomain,
                    gwMode: configTemplate.gwMode,
                    gwBypassLocal: configTemplate.gwBypassLocal,
                    gwUseSameCreds: configTemplate.gwUseSameCreds,
                    ignoreCert: configTemplate.ignoreCert
                )
                
                // Jump back to Main Thread to update config and initiate networking stack.
                await MainActor.run {
                    session.updateConfig(realConfig)
                    Task {
                        do {
                            try await session.connect()
                        } catch {
                            print("[SessionManager] Asynchronous connect failed: \(error)")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    print("[SessionManager] Keychain access failed in detached task: \(error)")
                    session.fail(with: error)
                }
            }
        }

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
