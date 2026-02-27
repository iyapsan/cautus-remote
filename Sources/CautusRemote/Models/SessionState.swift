import Foundation
import SwiftUI

/// Represents the current state of a remote session.
enum SessionState: Sendable {
    /// Session has not yet been initiated
    case idle
    /// Actively establishing connection
    case connecting
    /// Session is live and functional
    case connected
    /// Connection lost; attempting to re-establish (tracks retry count)
    case reconnecting(attempt: Int)
    /// Connection failed with an error
    case failed(SessionError)
    /// Session was intentionally closed
    case disconnected

    /// Whether the session is actively consuming resources
    var isActive: Bool {
        switch self {
        case .connecting, .connected, .reconnecting:
            return true
        default:
            return false
        }
    }

    /// Color for the sidebar status dot
    var statusColor: StatusColor {
        switch self {
        case .connected:
            return .green
        case .reconnecting:
            return .yellow
        case .failed:
            return .red
        default:
            return .none
        }
    }
}

// MARK: - Equatable

extension SessionState: Equatable {
    static func == (lhs: SessionState, rhs: SessionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.connecting, .connecting),
             (.connected, .connected),
             (.disconnected, .disconnected):
            return true
        case let (.reconnecting(a), .reconnecting(b)):
            return a == b
        case let (.failed(a), .failed(b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Status Color

/// Semantic color for status indicators.
enum StatusColor: Sendable {
    case green
    case yellow
    case red
    case none

    /// Convert to SwiftUI Color for rendering.
    var color: Color {
        switch self {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        case .none: return .gray.opacity(0.3)
        }
    }
}

// MARK: - Session Error

/// Typed error for session failures.
struct SessionError: Error, Equatable, Sendable {
    let code: ErrorCode
    let message: String

    enum ErrorCode: Equatable, Sendable {
        case authFailed
        case timeout
        case hostUnreachable
        case connectionRefused
        case keyNotFound
        case unknown
    }
}
