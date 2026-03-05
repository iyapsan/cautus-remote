import Foundation
import CRDPBridge

public class RDPContext: @unchecked Sendable {
    private var ctx: CRDPContextRef?
    
    // Certificate callback
    public typealias CertificateValidationCallback = (String, Int, String) -> Bool
    public var onVerifyCertificate: CertificateValidationCallback?
    
    // Clipboard callbacks
    /// Called on the RDP thread when Windows sends text to the Mac.
    public var onClipboardTextReceived: ((String) -> Void)?

    // Registry for C-Callback Context Bridging
    private static let registryLock = NSLock()
    nonisolated(unsafe) private static var contextRegistry: [Int: RDPContext] = [:]

    public init?() {
        guard let context = rdp_create() else { return nil }
        self.ctx = context
        
        RDPContext.registryLock.lock()
        RDPContext.contextRegistry[Int(bitPattern: context)] = self
        RDPContext.registryLock.unlock()
        
        // Certificate callback
        rdp_set_certificate_callbacks(context, { ctxRef, hostPtr, port, pemPtr, pemLength in
            guard let ctxRef = ctxRef else { return false }
            RDPContext.registryLock.lock()
            let rdpCtx = RDPContext.contextRegistry[Int(bitPattern: ctxRef)]
            RDPContext.registryLock.unlock()
            guard let rdp = rdpCtx, let cb = rdp.onVerifyCertificate,
                  let hostPtr = hostPtr, let pemPtr = pemPtr else { return false }
            let host = String(cString: hostPtr)
            let pemData = Data(bytes: pemPtr, count: Int(pemLength))
            let pemString = String(data: pemData, encoding: .ascii) ?? ""
            return cb(host, Int(port), pemString)
        })
        
        // Clipboard callbacks
        rdp_set_clipboard_callbacks(context,
            // text received FROM Windows
            { ctxRef, utf8Ptr, length in
                guard let ctxRef = ctxRef, let utf8Ptr = utf8Ptr else { return }
                RDPContext.registryLock.lock()
                let rdpCtx = RDPContext.contextRegistry[Int(bitPattern: ctxRef)]
                RDPContext.registryLock.unlock()
                guard let rdp = rdpCtx, let cb = rdp.onClipboardTextReceived else { return }
                let text = String(bytes: UnsafeBufferPointer(start: UnsafePointer<UInt8>(bitPattern: UInt(bitPattern: utf8Ptr))!, count: Int(length)), encoding: .utf8) ?? ""
                cb(text)
            }
        )
    }
    
    /// Push Mac clipboard text to Windows.
    public func sendClipboardText(_ text: String) {
        guard let ctx = ctx else { return }
        // cliprdr expects \r\n for line breaks, not just \n
        let crlfText = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: "\r\n")
        let cString = crlfText.cString(using: .utf8)
        cString?.withUnsafeBufferPointer { ptr in
            // cString includes the null terminator, so length is count - 1
            rdp_send_clipboard_text(ctx, ptr.baseAddress, ptr.count > 0 ? ptr.count - 1 : 0)
        }
    }
    
    deinit {
        destroy()
    }
    
    public func connect(host: String, port: Int = 3389, user: String, pass: String,
                        gwHost: String? = nil, gwUser: String? = nil, gwPass: String? = nil, gatewayAuthDomain: String? = nil,
                        gatewayMode: Int = 0, gatewayBypassLocal: Bool = true, gatewayUseSameCredentials: Bool? = nil, ignoreCert: Bool = false) -> Bool {
        guard let ctx = ctx else { return false }
        
        var finalGwUser = gwUser
        var finalGwDomain = gatewayAuthDomain
        
        if let userRaw = gwUser {
            if userRaw.contains("\\") {
                let parts = userRaw.split(separator: "\\", maxSplits: 1)
                if parts.count == 2 {
                    finalGwDomain = String(parts[0])
                    finalGwUser = String(parts[1])
                }
            } else if userRaw.contains("@") {
                finalGwUser = userRaw
                finalGwDomain = nil
            }
        }
        
        let finalGwSameCreds = gatewayUseSameCredentials ?? (gwUser == nil && gwPass == nil)

        print("[RDPContext] Connect called with ignoreCert: \(ignoreCert)")
        
        if ignoreCert {
            print("==========================================================================")
            print("WARNING: IGNORE CERTIFICATE IS TRUE. THIS IS A TESTING FLAG.")
            print("THIS BYPASSES ALL ENTERPRISE CERTIFICATE VERIFICATION.")
            print("==========================================================================")
        }
        
        let hostC = host.cString(using: .utf8)!
        let userC = user.cString(using: .utf8)!
        let passC = pass.cString(using: .utf8)!
        
        let gwHostC = gwHost?.cString(using: .utf8)
        let gwUserC = finalGwUser?.cString(using: .utf8)
        let gwPassC = gwPass?.cString(using: .utf8)
        let gwDomainC = finalGwDomain?.cString(using: .utf8)
        
        return hostC.withUnsafeBufferPointer { h in
            userC.withUnsafeBufferPointer { u in
                passC.withUnsafeBufferPointer { p in
                    
                    let gwH_ptr = gwHostC?.withUnsafeBufferPointer { $0.baseAddress } ?? nil
                    let gwU_ptr = gwUserC?.withUnsafeBufferPointer { $0.baseAddress } ?? nil
                    let gwP_ptr = gwPassC?.withUnsafeBufferPointer { $0.baseAddress } ?? nil
                    let gwD_ptr = gwDomainC?.withUnsafeBufferPointer { $0.baseAddress } ?? nil
                    
                    return rdp_connect(ctx, h.baseAddress, Int32(port), u.baseAddress, p.baseAddress,
                                       gwH_ptr, gwU_ptr, gwP_ptr, gwD_ptr,
                                       Int32(gatewayMode), gatewayBypassLocal, finalGwSameCreds, ignoreCert)
                }
            }
        }
    }
    
    public func poll(timeoutMs: Int = 100) -> Bool {
        guard let ctx = ctx else { return false }
        return rdp_poll(ctx, Int32(timeoutMs))
    }
    
    public func sendKeyboardInput(flags: UInt16, scancode: UInt16) {
        guard let ctx = ctx else { return }
        rdp_send_input_keyboard(ctx, flags, scancode)
    }
    
    public func sendMouseInput(flags: UInt16, x: UInt16, y: UInt16) {
        guard let ctx = ctx else { return }
        rdp_send_input_mouse(ctx, flags, x, y)
    }
    
    public func disconnect() {
        guard let ctx = ctx else { return }
        rdp_disconnect(ctx)
    }
    
    public func destroy() {
        if let ctx = ctx {
            RDPContext.registryLock.lock()
            RDPContext.contextRegistry.removeValue(forKey: Int(bitPattern: ctx))
            RDPContext.registryLock.unlock()
            
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
    
    public func printConfig() {
        guard let ctx = ctx else { return }
        rdp_print_config(ctx)
    }
    
    public static func printEnvReport() {
        rdp_print_env_report()
    }
}
