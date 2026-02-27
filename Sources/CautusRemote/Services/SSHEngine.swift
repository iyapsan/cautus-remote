import Foundation
import Combine
import NIOCore
import NIOPosix
import NIOSSH

/// SSH protocol engine built on SwiftNIO SSH.
///
/// Manages the NIO event loop group (shared across all sessions)
/// and implements `RemoteProtocol` for creating SSH connections.
@MainActor
final class SSHEngine: RemoteProtocol {
    let protocolName = "ssh"

    var supportedAuthMethods: [AuthMethod] {
        [.password, .publicKey]
    }

    /// Shared NIO event loop group for all SSH connections.
    /// Using 1 thread — sufficient for terminal I/O.
    private let eventLoopGroup: MultiThreadedEventLoopGroup

    init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
    }

    // MARK: - RemoteProtocol

    func connect(
        to connection: Connection,
        credential: Credential
    ) async throws -> any RemoteSession {
        let config = SSHConnectionConfig(
            host: connection.host,
            port: connection.port,
            username: connection.username,
            credential: credential,
            timeout: connection.connectionTimeout,
            keepaliveInterval: connection.keepaliveInterval
        )

        let session = SSHSession(
            connectionId: connection.id,
            eventLoopGroup: eventLoopGroup,
            config: config
        )

        try await session.connect()
        return session
    }

    func disconnect(session: any RemoteSession) async {
        await session.close()
    }
}
