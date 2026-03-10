import Foundation

/// Strongly typed errors for RDP Session failures.
public enum SessionError: LocalizedError, CustomNSError {
    case authenticationFailed(underlyingError: UInt32)
    case hostUnreachable(underlyingError: UInt32)
    case tlsError(underlyingError: UInt32)
    case certificateNotTrusted(underlyingError: UInt32)
    case logonFailure(underlyingError: UInt32)
    case connectionCancelled(underlyingError: UInt32)
    case unknown(underlyingError: UInt32)
    case general(String)
    
    public var errorDescription: String? {
        switch self {
        case .authenticationFailed(let code): return "Authentication failed (Error 0x\(String(format: "%08x", code)))"
        case .hostUnreachable(let code): return "Host is unreachable or DNS resolution failed (Error 0x\(String(format: "%08x", code)))"
        case .tlsError(let code): return "TLS or security negotiation error (Error 0x\(String(format: "%08x", code)))"
        case .certificateNotTrusted(let code): return "The server certificate was not trusted (Error 0x\(String(format: "%08x", code)))"
        case .logonFailure(let code): return "Logon failure. Incorrect credentials or account restricted (Error 0x\(String(format: "%08x", code)))"
        case .connectionCancelled(let code): return "Connection was cancelled (Error 0x\(String(format: "%08x", code)))"
        case .unknown(let code): return "Unknown connection error (Error 0x\(String(format: "%08x", code)))"
        case .general(let msg): return msg
        }
    }
    
    public static func fromFreeRDPError(_ code: UInt32) -> SessionError {
        if code == 0 { return .unknown(underlyingError: code) }
        
        switch code {
        case 0x0002000C, 0x00020009: // ERRCONNECT_LOGON_FAILURE / ERRCONNECT_AUTHENTICATION_FAILED
            return .logonFailure(underlyingError: code)
        case 0x00020014, 0x0002000D: // ERRCONNECT_DNS_ERROR / ERRCONNECT_DNS_NAME_NOT_FOUND
            return .hostUnreachable(underlyingError: code)
        case 0x00020002, 0x00020004: // ERRCONNECT_TLS_CONNECT_FAILED
            return .tlsError(underlyingError: code)
        case 0x00020006, 0x000B0002: // ERRCONNECT_CONNECT_CANCELLED / ERRCONNECT_CONNECT_TRANSPORT_FAILED
            return .connectionCancelled(underlyingError: code)
        case 0x00020008: // ERRCONNECT_SECURITY_NEGO_CONNECT_FAILED
            return .tlsError(underlyingError: code)
        default:
            return .unknown(underlyingError: code)
        }
    }
}
