import Foundation

/// Handle to an active remote session.
///
/// Each session corresponds to one terminal pane. The session manages
/// the bidirectional data stream and publishes state changes.
///
/// `@MainActor` isolated because session state is consumed by the UI layer
/// and model objects are not `Sendable`.
@MainActor
protocol RemoteSession: AnyObject {
    /// Unique session identifier
    var id: UUID { get }

    /// The connection configuration this session was opened from
    var connectionId: UUID { get }

    /// Current session state
    var state: SessionState { get }

    /// Write data to the remote end (user keyboard input).
    func write(_ data: Data) async throws

    /// Async stream of data received from the remote end (terminal output).
    var outputStream: AsyncStream<Data> { get }

    /// Resize the pseudo-terminal.
    ///
    /// - Parameters:
    ///   - cols: Number of columns
    ///   - rows: Number of rows
    func resize(cols: Int, rows: Int) async throws

    /// Attempt to reconnect after a failure or disconnection.
    func reconnect() async throws

    /// Gracefully close the session.
    func close() async
}
