import Foundation
import NIOCore
import NIOPosix
import NIOSSH

/// Concrete SSH session wrapping a SwiftNIO SSH child channel.
///
/// Bridges NIO's event-loop-based I/O to Swift concurrency via `AsyncStream`.
/// All public methods are `@MainActor` for consistency with the service layer;
/// NIO work is dispatched to the event loop internally.
@MainActor
final class SSHSession: RemoteSession {
    let id: UUID
    let connectionId: UUID

    // MARK: - State

    private(set) var state: SessionState = .idle

    // MARK: - I/O Streams

    /// Stream of data from the remote (terminal output)
    let outputStream: AsyncStream<Data>
    private let outputContinuation: AsyncStream<Data>.Continuation

    // MARK: - NIO Resources

    /// The parent SSH channel (TCP connection)
    private var parentChannel: Channel?

    /// The SSH child channel (shell session)
    private var childChannel: Channel?

    /// Event loop group (shared across sessions, owned by SSHEngine)
    private let eventLoopGroup: EventLoopGroup

    /// Connection configuration for reconnection
    private let connectionConfig: SSHConnectionConfig

    // MARK: - Reconnect State

    private var reconnectAttempt = 0
    private static let maxReconnectAttempts = 5
    private static let baseReconnectDelay: TimeInterval = 1.0

    // MARK: - Init

    init(
        connectionId: UUID,
        eventLoopGroup: EventLoopGroup,
        config: SSHConnectionConfig
    ) {
        self.id = UUID()
        self.connectionId = connectionId
        self.eventLoopGroup = eventLoopGroup
        self.connectionConfig = config

        // Set up output stream
        var continuation: AsyncStream<Data>.Continuation!
        self.outputStream = AsyncStream<Data> { c in
            continuation = c
        }
        self.outputContinuation = continuation
    }

    // MARK: - Connection

    /// Establish the SSH connection.
    func connect() async throws {
        state = .connecting

        do {
            // Create the auth delegate
            let authDelegate = CautusAuthDelegate(
                username: connectionConfig.username,
                credential: connectionConfig.credential
            )

            // Accept all host keys for now (TODO: host key verification in Phase 5)
            let serverAuthDelegate = AcceptAllHostKeysDelegate()

            let clientConfig = SSHClientConfiguration(
                userAuthDelegate: authDelegate,
                serverAuthDelegate: serverAuthDelegate
            )

            // Bootstrap the TCP connection
            let bootstrap = ClientBootstrap(group: eventLoopGroup)
                .channelInitializer { channel in
                    channel.pipeline.addHandlers([
                        NIOSSHHandler(
                            role: .client(clientConfig),
                            allocator: channel.allocator,
                            inboundChildChannelInitializer: nil
                        ),
                    ])
                }
                .connectTimeout(.seconds(Int64(connectionConfig.timeout)))
                .channelOption(.socketOption(.so_reuseaddr), value: 1)

            // Connect
            let channel = try await bootstrap.connect(
                host: connectionConfig.host,
                port: connectionConfig.port
            ).get()

            self.parentChannel = channel

            // Create SSH child channel for shell session
            try await self.openShellChannel(on: channel)

            state = .connected
            reconnectAttempt = 0

        } catch {
            let sessionError = Self.mapError(error)
            state = .failed(sessionError)
            throw sessionError
        }
    }

    /// Called when the SSH channel becomes inactive (remote disconnect/exit).
    func handleChannelClose() {
        guard state == .connected || state == .connecting else { return }
        state = .disconnected
        childChannel = nil
    }

    /// Open a shell channel on the SSH connection with PTY.
    private func openShellChannel(on channel: Channel) async throws {
        let sshHandler = try await channel.pipeline.handler(type: NIOSSHHandler.self).get()

        // Create child channel promise — must dispatch to event loop
        let childChannelPromise = channel.eventLoop.makePromise(of: Channel.self)
        let outputContinuation = self.outputContinuation

        channel.eventLoop.execute { [weak self] in
            sshHandler.createChannel(childChannelPromise, channelType: .session) { childChannel, channelType in
                guard channelType == .session else {
                    return childChannel.eventLoop.makeFailedFuture(SSHSessionError.unexpectedChannelType)
                }

                // Add our data handler to the child channel
                let dataHandler = SSHDataHandler(
                    outputContinuation: outputContinuation,
                    onClose: {
                        Task { @MainActor in
                            self?.handleChannelClose()
                        }
                    }
                )
                return childChannel.pipeline.addHandlers([dataHandler])
            }
        }

        let childChannel = try await childChannelPromise.futureResult.get()
        self.childChannel = childChannel

        // Request PTY
        let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: 80,
            terminalRowHeight: 24,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: SSHTerminalModes([:])
        )
        try await childChannel.triggerUserOutboundEvent(ptyRequest).get()

        // Request shell
        let shellRequest = SSHChannelRequestEvent.ShellRequest(wantReply: true)
        try await childChannel.triggerUserOutboundEvent(shellRequest).get()
    }

    // MARK: - RemoteSession Protocol

    func write(_ data: Data) async throws {
        guard let childChannel, state == .connected else {
            throw SessionError(code: .unknown, message: "Session not connected")
        }

        var buffer = childChannel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        let channelData = SSHChannelData(type: .channel, data: .byteBuffer(buffer))
        try await childChannel.writeAndFlush(channelData).get()
    }

    func resize(cols: Int, rows: Int) async throws {
        guard let childChannel, state == .connected,
              cols > 0, rows > 0 else { return }

        let windowChange = SSHChannelRequestEvent.WindowChangeRequest(
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0
        )
        try await childChannel.triggerUserOutboundEvent(windowChange).get()
    }

    func reconnect() async throws {
        guard reconnectAttempt < Self.maxReconnectAttempts else {
            state = .failed(SessionError(code: .timeout, message: "Max reconnect attempts exceeded"))
            return
        }

        reconnectAttempt += 1
        state = .reconnecting(attempt: reconnectAttempt)

        // Exponential backoff
        let delay = Self.baseReconnectDelay * pow(2.0, Double(reconnectAttempt - 1))
        try await Task.sleep(for: .seconds(delay))

        // Close existing channels
        await closeChannels()

        // Retry connection
        try await connect()
    }

    func close() async {
        await closeChannels()
        outputContinuation.finish()
        state = .disconnected
    }

    // MARK: - Private

    private func closeChannels() async {
        try? await childChannel?.close().get()
        try? await parentChannel?.close().get()
        childChannel = nil
        parentChannel = nil
    }

    /// Map NIO/SSH errors to our SessionError type.
    private static func mapError(_ error: Error) -> SessionError {
        let message = error.localizedDescription

        if let nioError = error as? NIOSSHError {
            if "\(nioError)".contains("auth") {
                return SessionError(code: .authFailed, message: message)
            }
        }

        if let ioError = error as? IOError {
            switch ioError.errnoCode {
            case ECONNREFUSED:
                return SessionError(code: .connectionRefused, message: message)
            case EHOSTUNREACH, ENETUNREACH:
                return SessionError(code: .hostUnreachable, message: message)
            case ETIMEDOUT:
                return SessionError(code: .timeout, message: message)
            default:
                break
            }
        }

        return SessionError(code: .unknown, message: message)
    }
}

// MARK: - SSH Connection Config

/// Immutable snapshot of connection parameters for (re)connection.
struct SSHConnectionConfig: Sendable {
    let host: String
    let port: Int
    let username: String
    let credential: Credential
    let timeout: Int
    let keepaliveInterval: Int
}

// MARK: - Session-Specific Errors

enum SSHSessionError: Error {
    case unexpectedChannelType
    case channelNotAvailable
}
