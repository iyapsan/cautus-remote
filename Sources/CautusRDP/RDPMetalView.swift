import Cocoa
import MetalKit

public class RDPMetalView: MTKView, MTKViewDelegate {
    public var rdp: RDPContext?
    private var commandQueue: MTLCommandQueue?
    
    private var isPolling = false
    
    public override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device)
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
        self.colorPixelFormat = .bgra8Unorm
        self.framebufferOnly = false
        self.autoResizeDrawable = false
        self.drawableSize = CGSize(width: 1280, height: 720)
        self.delegate = self
        self.preferredFramesPerSecond = 60
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func startRDPThread() {
        guard !isPolling else { return }
        isPolling = true
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            while self?.isPolling == true {
                // Poll continuously with a small timeout (e.g. 5ms) to process all network packets
                let _ = self?.rdp?.poll(timeoutMs: 5)
            }
        }
    }
    
    public func stopRDPThread() {
        isPolling = false
    }
    
    public override var acceptsFirstResponder: Bool { return true }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        guard let rdp = rdp else { return }
        
        guard let fb = rdp.getFramebuffer(), let drawable = view.currentDrawable else {
            return
        }
        
        // Ensure we don't copy out of bounds
        let copyWidth = min(fb.width, drawable.texture.width)
        let copyHeight = min(fb.height, drawable.texture.height)
        
        if copyWidth > 0 && copyHeight > 0 {
            let region = MTLRegionMake2D(0, 0, copyWidth, copyHeight)
            // Use replace(region...) to upload bits to the GPU without a shader
            drawable.texture.replace(region: region, mipmapLevel: 0, withBytes: fb.buffer, bytesPerRow: fb.stride)
            
            if let commandBuffer = commandQueue?.makeCommandBuffer() {
                commandBuffer.present(drawable)
                commandBuffer.commit()
            }
        }
    }
    
    // MARK: - Input Handling
    
    private var activeModifiers = Set<UInt16>()
    
    private func sendMouse(event: NSEvent, isDown: Bool) {
        let loc = convert(event.locationInWindow, from: nil)
        let x = UInt16(min(max(0, loc.x), bounds.width))
        let y = UInt16(min(max(0, bounds.height - loc.y), bounds.height))
        
        var flags: UInt16 = isDown ? 0x8000 : 0x0000
        flags |= 0x1000 // PTR_FLAGS_BUTTON1
        
        rdp?.sendMouseInput(flags: flags, x: x, y: y)
    }
    
    public override func mouseDown(with event: NSEvent) { sendMouse(event: event, isDown: true) }
    public override func mouseUp(with event: NSEvent) { sendMouse(event: event, isDown: false) }
    public override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let x = UInt16(min(max(0, loc.x), bounds.width))
        let y = UInt16(min(max(0, bounds.height - loc.y), bounds.height))
        rdp?.sendMouseInput(flags: 0x0800, x: x, y: y) // PTR_FLAGS_MOVE
    }
    
    public override func keyDown(with event: NSEvent) {
        let (scancode, isExt) = mapMacKeyCodeToRDP(event.keyCode)
        if scancode > 0 {
            var flags: UInt16 = event.isARepeat ? 0x4000 : 0x0000 // 0x4000 = Repeat, 0x0000 = Initial Down
            if isExt { flags |= 0x0100 } // KBD_FLAGS_EXTENDED
            rdp?.sendKeyboardInput(flags: flags, scancode: scancode)
        }
    }
    
    public override func keyUp(with event: NSEvent) {
        let (scancode, isExt) = mapMacKeyCodeToRDP(event.keyCode)
        if scancode > 0 {
            var flags: UInt16 = 0x8000 // KBD_FLAGS_RELEASE
            if isExt { flags |= 0x0100 }
            rdp?.sendKeyboardInput(flags: flags, scancode: scancode)
        }
    }
    
    public override func flagsChanged(with event: NSEvent) {
        let macCode = event.keyCode
        let (scancode, isExt) = mapMacKeyCodeToRDP(macCode)
        guard scancode > 0 else { return }
        
        // Determine whether this specific modifier key is currently pressed
        let isPressed: Bool
        switch macCode {
        case 56, 60: isPressed = event.modifierFlags.contains(.shift) // LShift / RShift
        case 59, 62: isPressed = event.modifierFlags.contains(.control) // LCtrl / RCtrl
        case 58, 61: isPressed = event.modifierFlags.contains(.option) // LAlt / RAlt
        case 55, 54: isPressed = event.modifierFlags.contains(.command) // LCmd / RCmd
        case 57: isPressed = event.modifierFlags.contains(.capsLock)
        default: return
        }
        
        var flags: UInt16 = isPressed ? 0x0000 : 0x8000 // 0x0000 is DOWN, 0x8000 is UP/RELEASE
        if isExt { flags |= 0x0100 }
        
        rdp?.sendKeyboardInput(flags: flags, scancode: scancode)
        print("flagsChanged: macKeyCode \(macCode) isPressed=\(isPressed) -> rdpScancode \(scancode)")
    }
    
    private func mapMacKeyCodeToRDP(_ macCode: UInt16) -> (UInt16, Bool) {
        switch macCode {
        case 53: return (0x01, false) // Esc
        case 18: return (0x02, false) // 1
        case 19: return (0x03, false) // 2
        case 20: return (0x04, false) // 3
        case 21: return (0x05, false) // 4
        case 23: return (0x06, false) // 5
        case 22: return (0x07, false) // 6
        case 26: return (0x08, false) // 7
        case 28: return (0x09, false) // 8
        case 25: return (0x0A, false) // 9
        case 29: return (0x0B, false) // 0
        case 27: return (0x0C, false) // Minus
        case 24: return (0x0D, false) // Equal
        case 51: return (0x0E, false) // Backspace
        case 48: return (0x0F, false) // Tab
        case 12: return (0x10, false) // Q
        case 13: return (0x11, false) // W
        case 14: return (0x12, false) // E
        case 15: return (0x13, false) // R
        case 17: return (0x14, false) // T
        case 16: return (0x15, false) // Y
        case 32: return (0x16, false) // U
        case 34: return (0x17, false) // I
        case 31: return (0x18, false) // O
        case 35: return (0x19, false) // P
        case 33: return (0x1A, false) // LBracket
        case 30: return (0x1B, false) // RBracket
        case 36: return (0x1C, false) // Return
        case 59: return (0x1D, false) // LCtrl
        case 0:  return (0x1E, false) // A
        case 1:  return (0x1F, false) // S
        case 2:  return (0x20, false) // D
        case 3:  return (0x21, false) // F
        case 5:  return (0x22, false) // G
        case 4:  return (0x23, false) // H
        case 38: return (0x24, false) // J
        case 40: return (0x25, false) // K
        case 37: return (0x26, false) // L
        case 41: return (0x27, false) // Semicolon
        case 39: return (0x28, false) // Quote
        case 50: return (0x29, false) // Grave
        case 56: return (0x2A, false) // LShift
        case 42: return (0x2B, false) // Backslash
        case 6:  return (0x2C, false) // Z
        case 7:  return (0x2D, false) // X
        case 8:  return (0x2E, false) // C
        case 9:  return (0x2F, false) // V
        case 11: return (0x30, false) // B
        case 45: return (0x31, false) // N
        case 46: return (0x32, false) // M
        case 43: return (0x33, false) // Comma
        case 47: return (0x34, false) // Period
        case 44: return (0x35, false) // Slash
        case 60: return (0x36, false) // RShift
        case 58: return (0x38, false) // LAlt/Option
        case 49: return (0x39, false) // Space
        case 57: return (0x3A, false) // CapsLock
        case 123: return (0x4B, true) // Left
        case 124: return (0x4D, true) // Right
        case 125: return (0x50, true) // Down
        case 126: return (0x48, true) // Up
        case 117: return (0x53, true) // Delete
        case 62: return (0x1D, true) // RCtrl
        case 61: return (0x38, true) // RAlt/Option
        case 55: return (0x5B, true) // LCmd -> LWin
        case 54: return (0x5C, true) // RCmd -> RWin
        default: return (0, false)
        }
    }
}
