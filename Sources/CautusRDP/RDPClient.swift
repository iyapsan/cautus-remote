import Foundation

/// Primary entry point for establishing new RDP sessions.
public struct RDPClient {
    
    public init() {}
    
    /// Establishes a connection in the background and returns the live session instance immediately.
    @MainActor
    public func connect(config: RDPConfig) -> RDPSession {
        let session = RDPSession(config: config)
        Task {
            do {
                try await session.connect()
            } catch {
                print("[RDPClient] Background connection failed: \(error)")
            }
        }
        return session
    }
}
