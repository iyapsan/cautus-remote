import Cocoa
import MetalKit

public final class PollingState: @unchecked Sendable {
    private let lock = NSLock()
    private var _isRunning = false
    public var isRunning: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isRunning }
        set { lock.lock(); defer { lock.unlock() }; _isRunning = newValue }
    }
    public init() {}
}

public class RDPMetalView: MTKView, MTKViewDelegate {
    public weak var session: RDPSession?
    private var commandQueue: MTLCommandQueue?
    
    // SOAK: Metrics reporting
    public let metrics = FrameMetrics()
    public var csvLogger: CSVLogger?
    
    public override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device)
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
        self.colorPixelFormat = .bgra8Unorm
        self.framebufferOnly = false
        self.autoResizeDrawable = false
        self.drawableSize = CGSize(width: 1280, height: 720)
        self.layerContentsPlacement = .scaleProportionallyToFit
        self.delegate = self
        self.preferredFramesPerSecond = 60
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    
    public override var acceptsFirstResponder: Bool { return true }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        let session = self.session

        if let commandBuffer = commandQueue?.makeCommandBuffer() {
            // If we have a framebuffer, we'll write the texture over it
            if let fb = session?.getFramebuffer() {
                    let copyWidth = min(fb.width, drawable.texture.width)
                    let copyHeight = min(fb.height, drawable.texture.height)
                    
                    if copyWidth > 0 && copyHeight > 0 {
                        let region = MTLRegionMake2D(0, 0, copyWidth, copyHeight)
                        metrics.uploadStart()
                        drawable.texture.replace(region: region, mipmapLevel: 0, withBytes: fb.buffer, bytesPerRow: fb.stride)
                        metrics.uploadEnd()
                        metrics.markFrame()
                    }
                }
                
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    // MARK: - Input Handling
    
    private var activeModifiers = Set<UInt16>()
    
    private func rdpCoordinates(from event: NSEvent) -> (x: UInt16, y: UInt16) {
        let loc = convert(event.locationInWindow, from: nil)
        let rdpW: CGFloat = drawableSize.width   // 1280
        let rdpH: CGFloat = drawableSize.height  // 720
        let viewW = bounds.width
        let viewH = bounds.height

        // layerContentsPlacement = .scaleProportionallyToFit means the content is
        // letterboxed/pillarboxed (aspect-ratio preserving) and centered in the view.
        let scale = min(viewW / rdpW, viewH / rdpH)
        let displayW = rdpW * scale
        let displayH = rdpH * scale
        let marginX = (viewW - displayW) / 2   // left/right blank margin
        let marginY = (viewH - displayH) / 2   // top/bottom blank margin (in AppKit flipped coords: bottom offset)

        // AppKit y=0 is at bottom; flip to top-down, then subtract margin
        let flippedY = viewH - loc.y
        let contentX = loc.x - marginX
        let contentY = flippedY - marginY

        let rdpX = contentX / scale
        let rdpY = contentY / scale

        let x = UInt16(max(0, min(rdpX, rdpW - 1)))
        let y = UInt16(max(0, min(rdpY, rdpH - 1)))
        return (x, y)
    }

    private func sendMouse(event: NSEvent, isDown: Bool, button: UInt16 = 0x1000) {
        let (x, y) = rdpCoordinates(from: event)
        var flags: UInt16 = isDown ? 0x8000 : 0x0000
        flags |= button
        session?.sendMouseInput(flags: flags, x: x, y: y)
    }

    public override func mouseDown(with event: NSEvent)      { sendMouse(event: event, isDown: true) }
    public override func mouseUp(with event: NSEvent)        { sendMouse(event: event, isDown: false) }
    public override func rightMouseDown(with event: NSEvent) { sendMouse(event: event, isDown: true, button: 0x2000) }
    public override func rightMouseUp(with event: NSEvent)   { sendMouse(event: event, isDown: false, button: 0x2000) }

    public override func mouseDragged(with event: NSEvent) {
        let (x, y) = rdpCoordinates(from: event)
        session?.sendMouseInput(flags: 0x0800, x: x, y: y) // PTR_FLAGS_MOVE
    }

    public override func scrollWheel(with event: NSEvent) {
        let (x, y) = rdpCoordinates(from: event)
        if event.scrollingDeltaY != 0 {
            // PTR_FLAGS_WHEEL = 0x0200, positive delta = scroll up (0x0078 +), negative = down (subtract from 0x0200)
            let delta = Int16(max(-127, min(127, Int(event.scrollingDeltaY * 3))))
            let wheelFlags: UInt16 = delta >= 0
                ? (0x0200 | UInt16(delta))
                : (0x0200 | 0x0100 | UInt16(-delta))   // PTR_FLAGS_WHEEL_NEGATIVE = 0x0100
            session?.sendMouseInput(flags: wheelFlags, x: x, y: y)
        }
    }
    
    public override func keyDown(with event: NSEvent) {
        let (scancode, isExt) = mapMacKeyCodeToRDP(event.keyCode)
        if scancode > 0 {
            var flags: UInt16 = event.isARepeat ? 0x4000 : 0x0000 // 0x4000 = Repeat, 0x0000 = Initial Down
            if isExt { flags |= 0x0100 } // KBD_FLAGS_EXTENDED
            session?.sendKeyboardInput(flags: flags, scancode: scancode)
        }
    }
    
    public override func keyUp(with event: NSEvent) {
        let (scancode, isExt) = mapMacKeyCodeToRDP(event.keyCode)
        if scancode > 0 {
            var flags: UInt16 = 0x8000 // KBD_FLAGS_RELEASE
            if isExt { flags |= 0x0100 }
            session?.sendKeyboardInput(flags: flags, scancode: scancode)
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
        
        session?.sendKeyboardInput(flags: flags, scancode: scancode)
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
