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
    
    public func getFramebuffer() -> (buffer: UnsafeMutablePointer<UInt8>, width: Int, height: Int, stride: Int)? {
        guard let ctx = ctx else { return nil }
        var bufferPtr: UnsafeMutableRawPointer? = nil
        var width: Int32 = 0
        var height: Int32 = 0
        var stride: Int32 = 0
        
        let success = rdp_get_framebuffer(ctx, &bufferPtr, &width, &height, &stride)
        guard success, let ptr = bufferPtr else { return nil }
        
        let typedPtr = ptr.bindMemory(to: UInt8.self, capacity: Int(stride * height))
        return (buffer: typedPtr, width: Int(width), height: Int(height), stride: Int(stride))
    }
}
