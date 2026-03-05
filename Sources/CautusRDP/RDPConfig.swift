import Foundation

public struct RDPConfig: Sendable {
    public let host: String
    public let port: Int
    public let user: String
    public let pass: String
    
    // Gateway settings
    public let gwHost: String?
    public let gwUser: String?
    public let gwPass: String?
    public let gwDomain: String?
    public let gwMode: Int
    public let gwBypassLocal: Bool
    public let gwUseSameCreds: Bool?
    
    // Debug/Testing flag
    public let ignoreCert: Bool
    
    public init(
        host: String, port: Int = 3389,
        user: String, pass: String,
        gwHost: String? = nil, gwUser: String? = nil, gwPass: String? = nil, gwDomain: String? = nil,
        gwMode: Int = 0, gwBypassLocal: Bool = true, gwUseSameCreds: Bool? = nil,
        ignoreCert: Bool = false
    ) {
        self.host = host
        self.port = port
        self.user = user
        self.pass = pass
        self.gwHost = gwHost
        self.gwUser = gwUser
        self.gwPass = gwPass
        self.gwDomain = gwDomain
        self.gwMode = gwMode
        self.gwBypassLocal = gwBypassLocal
        self.gwUseSameCreds = gwUseSameCreds
        self.ignoreCert = ignoreCert
    }
}
