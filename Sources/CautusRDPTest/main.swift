import Foundation
import CautusRDP

print("=== CautusRDP Swift Wrapper Test ===")

guard let rdp = RDPContext() else {
    print("ERROR: Failed to create RDPContext")
    exit(1)
}

print("Initiating connection to 192.168.64.2...")

let connected = rdp.connect(host: "192.168.64.2", port: 3389, user: "iyaps", pass: "P@ssw0rd")

if !connected {
    print("ERROR: Connection failed")
    exit(1)
}

print("CONNECTED! Running 10-second event loop...")

let timeout = Date().addingTimeInterval(10)
while Date() < timeout {
    let _ = rdp.poll(timeoutMs: 100)
}

let stats = rdp.getStats()
print("Event loop ended.")
print("Stats: \(stats.width)x\(stats.height) desktop, \(stats.fps) frames processed")

if let fb = rdp.getFramebuffer() {
    print("Capturing framebuffer: \(fb.width)x\(fb.height), stride \(fb.stride)...")
    let success = CautusRDPUtil.savePNG(buffer: fb.buffer, width: fb.width, height: fb.height, bpp: 32, path: "screenshot.png")
    print("Screenshot saved to screenshot.png: \(success)")
} else {
    print("Failed to get framebuffer.")
}

print("Disconnecting...")
rdp.disconnect()
print("Clean shutdown complete.")
exit(0)
