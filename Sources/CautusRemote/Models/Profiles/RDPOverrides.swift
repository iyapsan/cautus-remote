import Foundation

/// Connection-level RDP setting overrides.
/// Every field is optional — `nil` means "inherit from the folder chain or global defaults".
/// This is encoded as JSON data (`Connection.rdpOverridesData`) to avoid SwiftData migration pain.
public struct RDPOverrides: Codable, Equatable, Sendable {
    public var port: Int?
    public var colorDepth: RDPColorDepth?
    public var enableClipboard: Bool?
    public var enableNLA: Bool?
    public var gatewayMode: GatewayMode?
    public var gatewayBypassLocal: Bool?
    public var reconnectMaxAttempts: Int?
    public var scaling: RDPScalingMode?
    public var dynamicResolution: Bool?

    public init(
        port: Int? = nil,
        colorDepth: RDPColorDepth? = nil,
        enableClipboard: Bool? = nil,
        enableNLA: Bool? = nil,
        gatewayMode: GatewayMode? = nil,
        gatewayBypassLocal: Bool? = nil,
        reconnectMaxAttempts: Int? = nil,
        scaling: RDPScalingMode? = nil,
        dynamicResolution: Bool? = nil
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

    /// True when every field is nil (i.e. fully inherits from parent).
    public var isEmpty: Bool {
        port == nil && colorDepth == nil && enableClipboard == nil &&
        enableNLA == nil && gatewayMode == nil && gatewayBypassLocal == nil &&
        reconnectMaxAttempts == nil && scaling == nil && dynamicResolution == nil
    }
}
