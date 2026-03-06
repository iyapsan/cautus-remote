import Foundation

// MARK: - Supporting Enums (unchanged from previous version)

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

// MARK: - RDPResolvedConfig

/// A fully concrete RDP configuration — every field has a value.
///
/// Used by:
///   - The RDP engine (all fields required)
///   - Global defaults (baseline for the resolution pipeline)
///   - `diff(from:)` to compare resolved configs (not raw patches − nil in patches means inherit, not same value)
///
/// Renamed from `RDPProfileDefaults` per the formal spec.
public struct RDPResolvedConfig: Codable, Equatable, Sendable {
    public var port: Int
    public var colorDepth: RDPColorDepth
    public var scaling: RDPScalingMode
    public var dynamicResolution: Bool
    public var clipboardEnabled: Bool
    public var nlaRequired: Bool
    public var gatewayMode: GatewayMode
    public var gatewayBypassLocal: Bool
    public var reconnectAttempts: Int

    public init(
        port: Int = 3389,
        colorDepth: RDPColorDepth = .bpp32,
        scaling: RDPScalingMode = .fit,
        dynamicResolution: Bool = true,
        clipboardEnabled: Bool = true,
        nlaRequired: Bool = true,
        gatewayMode: GatewayMode = .auto,
        gatewayBypassLocal: Bool = true,
        reconnectAttempts: Int = 5
    ) {
        self.port = port
        self.colorDepth = colorDepth
        self.scaling = scaling
        self.dynamicResolution = dynamicResolution
        self.clipboardEnabled = clipboardEnabled
        self.nlaRequired = nlaRequired
        self.gatewayMode = gatewayMode
        self.gatewayBypassLocal = gatewayBypassLocal
        self.reconnectAttempts = reconnectAttempts
    }

    // MARK: - Patch Application

    /// Apply a patch, overwriting only non-nil fields.
    /// nil patch fields leave this config unchanged (inherit).
    /// This is the single canonical merge operation — both folder and connection patches use it.
    public func applying(_ patch: RDPPatch) -> RDPResolvedConfig {
        var r = self
        if let v = patch.port               { r.port = v }
        if let v = patch.colorDepth         { r.colorDepth = v }
        if let v = patch.scaling            { r.scaling = v }
        if let v = patch.dynamicResolution  { r.dynamicResolution = v }
        if let v = patch.clipboardEnabled   { r.clipboardEnabled = v }
        if let v = patch.nlaRequired        { r.nlaRequired = v }
        if let v = patch.gatewayMode        { r.gatewayMode = v }
        if let v = patch.gatewayBypassLocal { r.gatewayBypassLocal = v }
        if let v = patch.reconnectAttempts  { r.reconnectAttempts = v }
        return r
    }

    // MARK: - Validation

    /// Clamp values to valid ranges.
    /// Call at the end of every resolution pipeline — prevents corrupt profiles from bricking connections.
    public func validated() -> RDPResolvedConfig {
        var r = self
        r.port = min(max(r.port, 1), 65535)
        r.reconnectAttempts = min(max(r.reconnectAttempts, 0), 20)
        return r
    }

    // MARK: - Diff (resolved configs only)

    /// Fields in `self` that differ from `other`.
    /// Operates on fully resolved configs, NOT on RDPPatch —
    /// patch nil means "inherit" which is semantically different from "same value".
    public func diff(from other: RDPResolvedConfig) -> [(key: String, value: String)] {
        var result: [(String, String)] = []
        if port != other.port                             { result.append(("Port", "\(port)")) }
        if colorDepth != other.colorDepth                 { result.append(("Color Depth", colorDepth.displayName)) }
        if scaling != other.scaling                       { result.append(("Scaling", scaling.displayName)) }
        if dynamicResolution != other.dynamicResolution   { result.append(("Auto Resize Display", dynamicResolution ? "On" : "Off")) }
        if clipboardEnabled != other.clipboardEnabled     { result.append(("Clipboard Sharing", clipboardEnabled ? "On" : "Off")) }
        if nlaRequired != other.nlaRequired               { result.append(("NLA", nlaRequired ? "On" : "Off")) }
        if gatewayMode != other.gatewayMode               { result.append(("Gateway Mode", gatewayMode.displayName)) }
        if gatewayBypassLocal != other.gatewayBypassLocal { result.append(("Bypass Local", gatewayBypassLocal ? "On" : "Off")) }
        if reconnectAttempts != other.reconnectAttempts   { result.append(("Reconnect Attempts", "\(reconnectAttempts)")) }
        return result
    }

    // MARK: - Global Fallback

    /// Baseline fallback for tests and early v1.
    /// In production SessionManager, pass `AppSettings.rdpDefaults` explicitly.
    public static let global = RDPResolvedConfig()
}

// MARK: - Safe Logging

extension RDPResolvedConfig: CustomStringConvertible {
    public var description: String {
        "RDPResolvedConfig(port:\(port) depth:\(colorDepth.rawValue) clipboard:\(clipboardEnabled) " +
        "nla:\(nlaRequired) gw:\(gatewayMode) gwBypass:\(gatewayBypassLocal) " +
        "retries:\(reconnectAttempts) scaling:\(scaling) dynRes:\(dynamicResolution))"
    }
}
