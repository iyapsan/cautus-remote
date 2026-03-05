import Foundation

public enum RDPConnectionState: Equatable, CustomStringConvertible, Sendable {
    case idle
    case connecting
    case connected
    case reconnecting(attempt: Int, max: Int)
    case disconnected(Error?)
    
    public var description: String {
        switch self {
        case .idle: return "Idle"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .reconnecting(let attempt, let max): return "Reconnecting (Attempt \(attempt) of \(max))..."
        case .disconnected(let err):
            if let e = err {
                return "Disconnected (\(e.localizedDescription))"
            }
            return "Disconnected"
        }
    }
    
    public static func == (lhs: RDPConnectionState, rhs: RDPConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.connecting, .connecting), (.connected, .connected):
            return true
        case (.reconnecting(let lAtt, let lMax), .reconnecting(let rAtt, let rMax)):
            return lAtt == rAtt && lMax == rMax
        case (.disconnected(let lErr), .disconnected(let rErr)):
            return (lErr as NSError?) == (rErr as NSError?)
        default:
            return false
        }
    }
}
