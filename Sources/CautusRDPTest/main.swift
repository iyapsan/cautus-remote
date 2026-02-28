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

print("Disconnecting...")
rdp.disconnect()
print("Clean shutdown complete.")
exit(0)
