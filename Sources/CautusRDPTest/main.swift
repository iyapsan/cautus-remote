import Cocoa
import MetalKit
import CautusRDP

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var rdpView: RDPMetalView!
    var rdpSession: RDPSession!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let args = ProcessInfo.processInfo.arguments
        
        var host = "192.168.64.2"
        var user = "iyaps"
        var pass = "P@ssw0rd"
        
        var gwHost: String? = nil
        var gwUser: String? = nil
        var gwPass: String? = nil
        var gatewayAuthDomain: String? = nil
        
        var gatewayMode: Int = 0 // auto
        var gatewayBypassLocal = true
        var gatewayUseSameCredentials: Bool? = nil
        var ignoreCert = false
        
        var printConfig = false
        var envReport = false
        
        // Very basic simple arg parser
        for (i, arg) in args.enumerated() {
            if arg == "--host" && args.count > i + 1 { host = args[i+1] }
            if arg == "--user" && args.count > i + 1 { user = args[i+1] }
            if arg == "--pass" && args.count > i + 1 { pass = args[i+1] }
            if arg == "--gateway-host" && args.count > i + 1 { gwHost = args[i+1] }
            if arg == "--gateway-user" && args.count > i + 1 { gwUser = args[i+1] }
            if arg == "--gateway-pass" && args.count > i + 1 { gwPass = args[i+1] }
            if arg == "--gateway-domain" && args.count > i + 1 { gatewayAuthDomain = args[i+1] }
            if arg == "--gateway-mode" && args.count > i + 1 {
                let m = args[i+1]
                if m == "rpc" { gatewayMode = 2 }
                else if m == "http" { gatewayMode = 3 }
                else { gatewayMode = 0 }
            }
            if arg == "--gateway-bypass-local" && args.count > i + 1 { gatewayBypassLocal = (args[i+1] == "true") }
            if arg == "--gateway-same-creds" && args.count > i + 1 { gatewayUseSameCredentials = (args[i+1] == "true") }
            if arg == "--ignore-cert" { ignoreCert = true }
            if arg == "--print-config" { printConfig = true }
            if arg == "--env-report" { envReport = true }
        }
        
        let config = RDPConfig(
            host: host, port: 3389, user: user, pass: pass,
            gwHost: gwHost, gwUser: gwUser, gwPass: gwPass, gwDomain: gatewayAuthDomain,
            gwMode: gatewayMode, gwBypassLocal: gatewayBypassLocal, gwUseSameCreds: gatewayUseSameCredentials,
            ignoreCert: ignoreCert
        )
        let client = RDPClient()
        
        Task { @MainActor in
            do {
                self.rdpSession = try await client.connect(config: config)
            } catch {
                print("Failed to connect: \(error)")
                NSApp.terminate(nil)
            }
        }
        

        print("gateway=\(gwHost != nil ? "enabled" : "disabled") host=\(host) mode=rpc-http")
        print("Final connection established to \(host). Opening window...")
        
        let device = MTLCreateSystemDefaultDevice()
        rdpView = RDPMetalView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720), device: device)
        rdpView.session = rdpSession

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.center()
        window.title = "CautusRDP Spike Day 5"
        window.contentView = rdpView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(rdpView) // CRITICAL: Receive keystrokes
        let soakScript = SoakScript()
        let watchdog = HitchWatchdog()
        let fm = FileManager.default
        let outDir = URL(fileURLWithPath: NSHomeDirectory() + "/artifacts/soak/current")
        try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)
        let csvPath = outDir.appendingPathComponent("metrics.csv")
        
        let logger = try? CSVLogger(path: csvPath, header: "ts,phase,fps,frameUploadMs,queueDepth,width,height,bytesPerFrame,rssBytes,disconnects,resizes,displayMoves,maxHitchMs")
        rdpView.csvLogger = logger
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self, let win = self.window else { return }
                
                soakScript.updatePhase()
                let ms = self.rdpView.metrics
                let hitchSq = watchdog.maxHitchMs
                let ts = Int(Date().timeIntervalSince1970)
                let fbSize = self.rdpView.session?.getFramebuffer() != nil ? (self.rdpView.bounds.width * self.rdpView.bounds.height * 4) : 0
                
                // Log to CSV
                let row = "\(ts),\(soakScript.phase.rawValue),\(String(format: "%.1f", ms.fps)),\(String(format: "%.2f", ms.lastUploadMs)),0,\(Int(win.frame.width)),\(Int(win.frame.height)),\(Int(fbSize)),\(currentRSSBytes()),\(soakScript.disconnects),\(soakScript.resizes),\(soakScript.displayMoves),\(String(format: "%.1f", hitchSq))"
                try? logger?.writeLine(row)
                
                // Execute script behavior
                if soakScript.phase == .resizeStorm {
                    let scale = soakScript.getScale(elapsed: Date().timeIntervalSince(soakScript.t0))
                    let newW = 1280.0 * scale
                    let newH = 720.0 * scale
                    win.setFrame(NSRect(x: win.frame.origin.x, y: win.frame.origin.y, width: newW, height: newH), display: true)
                    soakScript.resizes += 1
                } else if soakScript.phase == .reconnect {
                    print("Soak test complete (30 min). Shutting down...")
                    NSApp.terminate(nil)
                }
            }
        }
        
        // Ensure app comes to foreground
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        print("Disconnecting...")
        rdpSession.disconnect()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
