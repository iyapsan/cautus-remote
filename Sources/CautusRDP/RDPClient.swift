import Foundation

/// Primary entry point for establishing new RDP sessions.
public struct RDPClient {
    
    public init() {}
    
    /// Asynchronously establishes a connection and returns the live session instance.
    @MainActor
    public func connect(config: RDPConfig) async throws -> RDPSession {
        let session = RDPSession(config: config)
        try await session.connect()
        return session
    }
}
