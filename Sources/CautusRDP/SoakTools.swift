import Foundation
import MetalKit
import QuartzCore
import AppKit
import MachO

// MARK: - Frame Metrics
public final class FrameMetrics {
    public private(set) var fps: Double = 0
    private var frameCount = 0
    private var lastFpsT: CFTimeInterval = CACurrentMediaTime()
    
    public private(set) var lastUploadMs: Double = 0
    private var uploadStartT: CFTimeInterval = 0
    
    public init() {}
    
    public func markFrame() {
        frameCount += 1
        let now = CACurrentMediaTime()
        let dt = now - lastFpsT
        if dt >= 1.0 {
            fps = Double(frameCount) / dt
            frameCount = 0
            lastFpsT = now
        }
    }
    
    public func uploadStart() { uploadStartT = CACurrentMediaTime() }
    public func uploadEnd() {
        lastUploadMs = (CACurrentMediaTime() - uploadStartT) * 1000.0
    }
}

// MARK: - Memory Telemetry
public func currentRSSBytes() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    guard kerr == KERN_SUCCESS else { return 0 }
    return UInt64(info.resident_size)
}

// MARK: - Hitch Watchdog
public final class AtomicDouble: @unchecked Sendable {
    private let lock = NSLock()
    private var _val: Double = 0
    public init() {}
    public func updateMax(_ v: Double) { 
        lock.lock()
        defer { lock.unlock() }
        if v > _val { _val = v }
    }
    public func get() -> Double {
        lock.lock()
        defer { lock.unlock() }
        return _val
    }
}

public final class HitchWatchdog: @unchecked Sendable {
    private let queue = DispatchQueue(label: "soak.watchdog", qos: .userInteractive)
    public let atomicMax = AtomicDouble()
    private var isRunning = true

    public var maxHitchMs: Double { return atomicMax.get() }

    public init() {
        let maxVal = self.atomicMax
        queue.async { [weak self] in
            while self?.isRunning == true {
                let start = CACurrentMediaTime()
                let group = DispatchGroup()
                group.enter()

                DispatchQueue.main.async {
                    let hitch = (CACurrentMediaTime() - start) * 1000.0
                    maxVal.updateMax(hitch)
                    group.leave()
                }

                _ = group.wait(timeout: .now() + 1.0)
                usleep(50_000)
            }
        }
    }
    
    public func stop() {
        isRunning = false
    }
}

// MARK: - CSV Logger
public final class CSVLogger {
    private let handle: FileHandle
    private let queue = DispatchQueue(label: "soak.csv")
    
    public init(path: URL, header: String) throws {
        // Ensure directory exists
        let dir = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        FileManager.default.createFile(atPath: path.path, contents: nil)
        handle = try FileHandle(forWritingTo: path)
        try writeLine(header)
    }
    
    public func writeLine(_ line: String) throws {
        let data = (line + "\n").data(using: .utf8)!
        try queue.sync {
            try handle.write(contentsOf: data)
        }
    }
    
    deinit { try? handle.close() }
}

// MARK: - Script Actions
public enum SoakPhase: String { case warmup, resizeStorm, displayMove, inputStress, idle, reconnect }

public final class SoakScript {
    public private(set) var phase: SoakPhase = .warmup
    public private(set) var t0 = Date()
    public var disconnects = 0
    public var resizes = 0
    public var displayMoves = 0
    
    public init() {}
    
    public func updatePhase() {
        let elapsed = Date().timeIntervalSince(t0)
        switch elapsed {
        case 0..<120: phase = .warmup
        case 120..<600: phase = .resizeStorm
        case 600..<900: phase = .displayMove
        case 900..<1200: phase = .inputStress
        case 1200..<1680: phase = .idle
        default: phase = .reconnect
        }
    }
    
    public func getScale(elapsed: TimeInterval) -> CGFloat {
        // oscillate size
        return (Int(elapsed / 2.0) % 2 == 0) ? 0.7 : 1.1
    }
}
