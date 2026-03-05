import Foundation
import Combine
import AppKit
import Security
import CommonCrypto
import CRDPBridge

/// Represents an active or pending RDP connection session.
@MainActor
public final class RDPSession: ObservableObject, @unchecked Sendable {
    @Published public private(set) var state: RDPConnectionState = .idle
    @Published public private(set) var stats = CRDPStats()
    
    let config: RDPConfig
    private var context: RDPContext?
    private var isRunning = false
    private var lastPasteboardChangeCount: Int = NSPasteboard.general.changeCount
    
    // Reconnect tracking
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 5
    private var pollTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var generation: UInt64 = 0 // bumps every connect/disconnect
    
    init(config: RDPConfig) {
        self.config = config
    }
    
    public func connect() async throws {
        // Only allow connecting if idle or fully disconnected
        switch state {
        case .idle, .disconnected:
            break
        case .connected, .connecting, .reconnecting:
            return
        }
        state = .connecting
        generation &+= 1
        let currentGen = generation
        isRunning = true
        
        await rebuildContextForReconnect()
        
        guard let _ = self.context else {
            let err = NSError(domain: "CautusRDP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate RDP context"])
            state = .disconnected(err)
            throw err
        }
        
        print("[RDPSession] Connecting to \(self.config.host):\(self.config.port)...")
        let success = await tryConnectOnce()
        
        // Guard against stale connect attempts if user already cancelled
        if generation != currentGen || !isRunning { return }
        
        print("[RDPSession] Connection attempt finished. Success: \(success)")
        
        if success {
            state = .connected
            startPolling()
        } else {
            print("[RDPSession] Connection failed!")
            let err = NSError(domain: "CautusRDP", code: 2, userInfo: [NSLocalizedDescriptionKey: "Connection failed"])
            state = .disconnected(err)
            throw err
        }
    }
    
    private func rebuildContextForReconnect() {
        destroyContextIfNeeded()
        
        guard let ctx = RDPContext() else {
            print("[RDPSession] Failed to allocate RDP context during rebuild")
            return
        }
        
        self.context = ctx
        
        // Route certificate verification to the main thread via NSAlert
        let ignoreCertificateErrors = self.config.ignoreCert
        ctx.onVerifyCertificate = { host, port, pemString in
            if ignoreCertificateErrors { return true }
            return Self.presentCertificateAlert(host: host, pemString: pemString)
        }
        
        // Clipboard: Windows → Mac (write to NSPasteboard on main thread)
        ctx.onClipboardTextReceived = { [weak self] (text: String) in
            DispatchQueue.main.async {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(text, forType: .string)
                self?.lastPasteboardChangeCount = pb.changeCount
                print("[RDPSession] Clipboard: received \(text.count) chars from Windows")
            }
        }
    }
    
    private func tryConnectOnce() async -> Bool {
        guard let ctx = self.context else { return false }
        
        return await Task.detached {
            return ctx.connect(
                host: self.config.host,
                port: self.config.port,
                user: self.config.user,
                pass: self.config.pass,
                gwHost: self.config.gwHost,
                gwUser: self.config.gwUser,
                gwPass: self.config.gwPass,
                gatewayAuthDomain: self.config.gwDomain,
                gatewayMode: self.config.gwMode,
                gatewayBypassLocal: self.config.gwBypassLocal,
                gatewayUseSameCredentials: self.config.gwUseSameCreds,
                ignoreCert: self.config.ignoreCert
            )
        }.value
    }
    /// Starts the background runloop to poll the FreeRDP context
    private func startPolling() {
        pollTask?.cancel()
        
        let currentGen = self.generation
        
        pollTask = Task.detached { [weak self] in
            guard let self = self else { return }
            
            while await self.isRunning && !Task.isCancelled {
                // Bail out immediately if the generation has changed
                if await self.generation != currentGen { return }
                
                guard let ctx = await self.context else { break }
                let ok = ctx.poll(timeoutMs: 10)
                
                if !ok {
                    let wasRunning = await self.isRunning
                    await MainActor.run {
                        if wasRunning {
                            print("[RDPSession] Unexpected termination detected during poll. Triggering reconnect loop.")
                            self.beginReconnectLoop(reason: "Network Drop / Timeout")
                        }
                    }
                    break
                }
                
                // Update stats occasionally
                let frameCount = ctx.getStats().fps
                if frameCount % 30 == 0 {
                    let newStats = ctx.getStats()
                    await MainActor.run {
                        self.stats = newStats
                    }
                }
                
                // Track macOS clipboard changes
                await MainActor.run {
                    let currentChangeCount = NSPasteboard.general.changeCount
                    if currentChangeCount != self.lastPasteboardChangeCount {
                        self.lastPasteboardChangeCount = currentChangeCount
                        if let text = NSPasteboard.general.string(forType: .string) {
                            ctx.sendClipboardText(text)
                        }
                    }
                }
                
                // Yield to prevent pegging CPU too hard if poll is fast
                await Task.yield()
            }
        }
    }
    
    private func backoffSeconds(attempt: Int) -> Double {
        let base = min(pow(2.0, Double(attempt - 1)), 15.0)
        let jitter = Double.random(in: 0...(base * 0.2))
        return base + jitter
    }
    
    private func beginReconnectLoop(reason: String) {
        reconnectTask?.cancel()
        
        let myGen = generation
        reconnectTask = Task.detached { [weak self] in
            guard let self = self else { return }
            
            while true {
                if Task.isCancelled { return }
                
                let running = await self.isRunning
                let gen = await self.generation
                if !running || gen != myGen { return }
                
                let attempt = await self.reconnectAttempt
                let maxAtt = await self.maxReconnectAttempts
                
                if attempt >= maxAtt {
                    await MainActor.run {
                        self.state = .disconnected(NSError(domain: "CautusRDP", code: 3, userInfo: [NSLocalizedDescriptionKey: "Connection lost (\(reason))"]))
                    }
                    return
                }
                
                let nextAttempt = attempt + 1
                await MainActor.run { self.reconnectAttempt = nextAttempt }
                
                let delay = await self.backoffSeconds(attempt: nextAttempt)
                
                await MainActor.run { self.state = .reconnecting(attempt: nextAttempt, max: maxAtt) }
                
                // Sleep cancellably
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return // Task was cancelled
                }
                
                let runCheck = await self.isRunning
                let genCheck = await self.generation
                if Task.isCancelled || !runCheck || genCheck != myGen { return }
                
                // Tear down & rebuild context
                await MainActor.run { self.rebuildContextForReconnect() }
                
                // Attempt connect
                let ok = await self.tryConnectOnce()
                
                if ok {
                    await MainActor.run {
                        self.reconnectAttempt = 0
                        self.state = .connected
                        self.startPolling()
                    }
                    return
                } else {
                    // loop again for next attempt
                    continue
                }
            }
        }
    }
    
    private func destroyContextIfNeeded() {
        if let ctx = self.context {
            ctx.disconnect()
            ctx.destroy()
            self.context = nil
        }
    }
    
    // MARK: - API
    
    public func disconnect() {
        isRunning = false
        generation &+= 1 // Invalidates any active polling or connecting tasks
        
        pollTask?.cancel()
        reconnectTask?.cancel()
        
        destroyContextIfNeeded()
        state = .disconnected(nil)
    }
    
    public func sendKeyboardInput(flags: UInt16, scancode: UInt16) {
        context?.sendKeyboardInput(flags: flags, scancode: scancode)
    }
    
    public func sendMouseInput(flags: UInt16, x: UInt16, y: UInt16) {
        context?.sendMouseInput(flags: flags, x: x, y: y)
    }
    
    public func getFramebuffer() -> (buffer: UnsafeMutablePointer<UInt8>, width: Int, height: Int, stride: Int)? {
        return context?.getFramebuffer()
    }
    
    public func markFramePresented() {
        context?.markFramePresented()
    }
    
    // MARK: - Certificate Trust UI

    private static func parseCertificate(from pemString: String) -> (subject: String, issuer: String, fingerprint: String)? {
        // Strip PEM headers and decode base64 to get DER data
        let lines = pemString.components(separatedBy: "\n").filter {
            !$0.hasPrefix("-----BEGIN") && !$0.hasPrefix("-----END") && !$0.isEmpty
        }
        guard let derData = Data(base64Encoded: lines.joined()) else { return nil }
        guard let cert = SecCertificateCreateWithData(nil, derData as CFData) else { return nil }

        // Extract subject and issuer
        var commonName: CFString?
        SecCertificateCopyCommonName(cert, &commonName)
        let subject = (commonName as String?) ?? "Unknown"

        var issuerCN: CFString?
        if let issuerData = SecCertificateCopyNormalizedIssuerSequence(cert) {
            // Simple: just show the raw issuer string via summary
            let issuerCert = SecCertificateCopySubjectSummary(cert)
            issuerCN = issuerCert
        }
        let issuer = (issuerCN as String?) ?? "Unknown"

        // SHA-1 fingerprint
        let derBytes = derData
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        derBytes.withUnsafeBytes { _ = CC_SHA1($0.baseAddress, CC_LONG(derBytes.count), &digest) }
        let fingerprint = digest.map { String(format: "%02X", $0) }.joined(separator: ":")

        return (subject, issuer, fingerprint)
    }

    private static func presentCertificateAlert(host: String, pemString: String) -> Bool {
        var accepted = false
        DispatchQueue.main.sync {
            let alert = NSAlert()
            alert.messageText = "Certificate Not Verified"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Connect")
            alert.addButton(withTitle: "Cancel")

            if let parsed = parseCertificate(from: pemString) {
                alert.informativeText = """
                The server "\(host)" could not be verified with a trusted certificate.

                Common Name:  \(parsed.subject)
                Issued By:    \(parsed.issuer)
                Fingerprint:  \(parsed.fingerprint)

                If you trust this server, click Connect. Otherwise, click Cancel.
                """
            } else {
                alert.informativeText = """
                The server "\(host)" presented a self-signed or unrecognised certificate.

                Your connection may not be secure. Click Connect to proceed anyway, or Cancel to abort.
                """
            }

            let response = alert.runModal()
            accepted = (response == .alertFirstButtonReturn)

            // Restore first responder to the RDPMetalView so mouse/keyboard input works immediately
            if let window = NSApp.keyWindow, let contentView = window.contentView {
                window.makeKey()
                // Walk the view hierarchy to find the RDPMetalView and make it first responder
                func findRDPView(_ view: NSView) -> NSView? {
                    if NSStringFromClass(type(of: view)).contains("RDPMetalView") { return view }
                    for sub in view.subviews {
                        if let found = findRDPView(sub) { return found }
                    }
                    return nil
                }
                if let rdpView = findRDPView(contentView) {
                    window.makeFirstResponder(rdpView)
                }
            }
        }
        return accepted
    }
}
