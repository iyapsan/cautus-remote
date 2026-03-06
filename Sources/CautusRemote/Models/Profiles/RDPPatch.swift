import Foundation

/// Partial RDP configuration patch.
///
/// Used by:
///   - `Folder.rdpPatch` — folder-level overrides (any subset of fields)
///   - `Connection.rdpPatch` — connection-level overrides (highest priority)
///
/// Every field is optional. `nil` means **inherit from parent** — semantically distinct
/// from an empty `RDPPatch()` where all fields are nil (means: no overrides at all).
///
/// Renamed from `RDPOverrides` per the formal spec.
public struct RDPPatch: Codable, Equatable, Sendable {
    public var port: Int?
    public var colorDepth: RDPColorDepth?
    public var scaling: RDPScalingMode?
    public var dynamicResolution: Bool?
    public var clipboardEnabled: Bool?
    public var nlaRequired: Bool?
    public var gatewayMode: GatewayMode?
    public var gatewayBypassLocal: Bool?
    public var reconnectAttempts: Int?

    public init(
        port: Int? = nil,
        colorDepth: RDPColorDepth? = nil,
        scaling: RDPScalingMode? = nil,
        dynamicResolution: Bool? = nil,
        clipboardEnabled: Bool? = nil,
        nlaRequired: Bool? = nil,
        gatewayMode: GatewayMode? = nil,
        gatewayBypassLocal: Bool? = nil,
        reconnectAttempts: Int? = nil
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

    /// True when every field is nil — semantically "no overrides at all".
    /// Distinct from a non-nil `RDPPatch` where some fields happen to equal the inherited value.
    public var isEmpty: Bool {
        port == nil && colorDepth == nil && scaling == nil &&
        dynamicResolution == nil && clipboardEnabled == nil &&
        nlaRequired == nil && gatewayMode == nil &&
        gatewayBypassLocal == nil && reconnectAttempts == nil
    }
}
