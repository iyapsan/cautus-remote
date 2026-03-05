import Foundation

// MARK: - Supporting Enums

public enum RDPColorDepth: Int, Codable, CaseIterable, Sendable {
    case bpp16 = 16
    case bpp24 = 24
    case bpp32 = 32

    public var displayName: String {
        switch self {
        case .bpp16: return "High Color (16-bit)"
        case .bpp24: return "True Color (24-bit)"
        case .bpp32: return "Highest Quality (32-bit)"
        }
    }
}

public enum GatewayMode: Int, Codable, CaseIterable, Sendable {
    case never  = 0
    case auto   = 1
    case always = 2

    public var displayName: String {
        switch self {
        case .never:  return "Never"
        case .auto:   return "Auto"
        case .always: return "Always"
        }
    }
}

public enum RDPScalingMode: Int, Codable, CaseIterable, Sendable {
    case native = 0
    case fit    = 1

    public var displayName: String {
        switch self {
        case .native: return "Native (1:1)"
        case .fit:    return "Fit to Window"
        }
    }
}

// MARK: - RDPProfileDefaults

/// Non-optional struct — every field has a concrete value.
/// Used at the Folder and Global levels.
/// At test/early-v1 time, use .global as the fallback.
/// In production SessionManager, pass AppSettings.rdpDefaults instead.
public struct RDPProfileDefaults: Codable, Equatable, Sendable {
    public var port: Int
    public var colorDepth: RDPColorDepth
    public var enableClipboard: Bool
    public var enableNLA: Bool
    public var gatewayMode: GatewayMode
    public var gatewayBypassLocal: Bool
    public var reconnectMaxAttempts: Int
    public var scaling: RDPScalingMode
    public var dynamicResolution: Bool

    public init(
        port: Int = 3389,
        colorDepth: RDPColorDepth = .bpp32,
        enableClipboard: Bool = true,
        enableNLA: Bool = true,
        gatewayMode: GatewayMode = .auto,
        gatewayBypassLocal: Bool = true,
        reconnectMaxAttempts: Int = 5,
        scaling: RDPScalingMode = .fit,
        dynamicResolution: Bool = true
    ) {
        self.port = port
        self.colorDepth = colorDepth
        self.enableClipboard = enableClipboard
        self.enableNLA = enableNLA
        self.gatewayMode = gatewayMode
        self.gatewayBypassLocal = gatewayBypassLocal
        self.reconnectMaxAttempts = reconnectMaxAttempts
        self.scaling = scaling
        self.dynamicResolution = dynamicResolution
    }

    // MARK: - Validation

    /// Sanitize user-supplied values to valid ranges.
    /// Always call at the end of the resolution pipeline — prevents profile corruption bricking connections.
    public func validated() -> RDPProfileDefaults {
        var x = self
        x.port = min(max(x.port, 1), 65535)
        x.reconnectMaxAttempts = min(max(x.reconnectMaxAttempts, 0), 20)
        return x
    }

    // MARK: - Diff

    /// Fields in `self` that differ from `other`, returned as human-readable key-value pairs.
    /// Used in FolderDefaultsSheetView to show "Overriding: port=3390, NLA=Off".
    public func diff(from other: RDPProfileDefaults) -> [(key: String, value: String)] {
        var result: [(String, String)] = []
        if port != other.port                         { result.append(("Port", "\(port)")) }
        if colorDepth != other.colorDepth             { result.append(("Color Depth", colorDepth.displayName)) }
        if enableClipboard != other.enableClipboard   { result.append(("Clipboard", enableClipboard ? "On" : "Off")) }
        if enableNLA != other.enableNLA               { result.append(("NLA", enableNLA ? "On" : "Off")) }
        if gatewayMode != other.gatewayMode           { result.append(("Gateway Mode", gatewayMode.displayName)) }
        if gatewayBypassLocal != other.gatewayBypassLocal { result.append(("Gateway Bypass Local", gatewayBypassLocal ? "On" : "Off")) }
        if reconnectMaxAttempts != other.reconnectMaxAttempts { result.append(("Max Reconnects", "\(reconnectMaxAttempts)")) }
        if scaling != other.scaling                   { result.append(("Scaling", scaling.displayName)) }
        if dynamicResolution != other.dynamicResolution { result.append(("Dynamic Resolution", dynamicResolution ? "On" : "Off")) }
        return result
    }

    // MARK: - Global Fallback

    /// Safe fallback for tests and early v1.
    /// In production, prefer passing `AppSettings.rdpDefaults` explicitly.
    public static let global = RDPProfileDefaults()
}

// MARK: - Safe Logging

extension RDPProfileDefaults: CustomStringConvertible {
    /// Redacted-safe description. No credentials are held here, but marked explicitly for clarity.
    public var description: String {
        "RDPDefaults(port:\(port) depth:\(colorDepth.rawValue) clipboard:\(enableClipboard) " +
        "nla:\(enableNLA) gw:\(gatewayMode) gwBypass:\(gatewayBypassLocal) " +
        "retries:\(reconnectMaxAttempts) scaling:\(scaling) dynRes:\(dynamicResolution))"
    }
}
