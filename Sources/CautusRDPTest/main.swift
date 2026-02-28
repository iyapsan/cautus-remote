import Cocoa
import MetalKit
import CautusRDP

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var rdpView: RDPMetalView!
    var rdpContext: RDPContext!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let ctx = RDPContext() else {
            fatalError("Failed to init RDPContext")
        }
        self.rdpContext = ctx
        
        let connected = rdpContext.connect(host: "192.168.64.2", port: 3389, user: "iyaps", pass: "P@ssw0rd")
        if !connected {
            fatalError("Failed to connect")
        }
        print("Connected to 192.168.64.2. Opening window...")
        
        let device = MTLCreateSystemDefaultDevice()
        rdpView = RDPMetalView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720), device: device)
        rdpView.rdp = rdpContext

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.center()
        window.title = "CautusRDP Spike Day 5"
        window.contentView = rdpView
        window.makeKeyAndOrderFront(nil)
        
        // Ensure app comes to foreground
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        print("Disconnecting...")
        rdpContext.disconnect()
        rdpContext.destroy()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
