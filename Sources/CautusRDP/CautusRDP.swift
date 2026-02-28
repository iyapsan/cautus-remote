import Foundation
import CRDPBridge

public class RDPContext {
    private var ctx: CRDPContextRef?
    
    public init?() {
        guard let context = rdp_create() else { return nil }
        self.ctx = context
    }
    
    deinit {
        destroy()
    }
    
    public func connect(host: String, port: Int = 3389, user: String, pass: String) -> Bool {
        guard let ctx = ctx else { return false }
        
        let hostC = host.cString(using: .utf8)!
        let userC = user.cString(using: .utf8)!
        let passC = pass.cString(using: .utf8)!
        
        return hostC.withUnsafeBufferPointer { h in
            userC.withUnsafeBufferPointer { u in
                passC.withUnsafeBufferPointer { p in
                    rdp_connect(ctx, h.baseAddress, Int32(port), u.baseAddress, p.baseAddress)
                }
            }
        }
    }
    
    public func poll(timeoutMs: Int = 100) -> Bool {
        guard let ctx = ctx else { return false }
        return rdp_poll(ctx, Int32(timeoutMs))
    }
    
    public func disconnect() {
        guard let ctx = ctx else { return }
        rdp_disconnect(ctx)
    }
    
    public func destroy() {
        if let ctx = ctx {
            rdp_destroy(ctx)
            self.ctx = nil
        }
    }
    
    public func getStats() -> CRDPStats {
        guard let ctx = ctx else { return CRDPStats() }
        return rdp_get_stats(ctx)
    }
}
