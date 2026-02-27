import Foundation
import Combine

/// Abstraction for any remote connection protocol (SSH, VNC, RDP, Telnet).
///
/// v1 implements only SSH via `SSHEngine`. Future protocols conform to
/// this same interface and register with a protocol registry.
///
/// `@MainActor` isolated because `Connection` model objects are not `Sendable`.
@MainActor
protocol RemoteProtocol {
    /// Unique identifier for this protocol type (e.g. "ssh", "vnc")
    var protocolName: String { get }

    /// Authentication methods this protocol supports
    var supportedAuthMethods: [AuthMethod] { get }

    /// Establish a connection, returning an active session handle.
    ///
    /// - Parameters:
    ///   - connection: The connection configuration
    ///   - credential: Runtime credential from Keychain
    /// - Returns: A live `RemoteSession` handle
    func connect(
        to connection: Connection,
        credential: Credential
    ) async throws -> any RemoteSession

    /// Gracefully disconnect a session.
    func disconnect(session: any RemoteSession) async
}
