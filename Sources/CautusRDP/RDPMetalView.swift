import Cocoa
import MetalKit

public class RDPMetalView: MTKView, MTKViewDelegate {
    public var rdp: RDPContext?
    private var commandQueue: MTLCommandQueue?
    
    public override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device)
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
        self.colorPixelFormat = .bgra8Unorm
        self.framebufferOnly = false // Allow replacement directly
        self.delegate = self
        self.preferredFramesPerSecond = 30
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var acceptsFirstResponder: Bool { return true }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        guard let rdp = rdp else { return }
        
        // Pump event loop
        _ = rdp.poll(timeoutMs: 0)
        
        guard let fb = rdp.getFramebuffer(), let drawable = view.currentDrawable else {
            return
        }
        
        // Ensure we don't copy out of bounds
        let copyWidth = min(fb.width, drawable.texture.width)
        let copyHeight = min(fb.height, drawable.texture.height)
        
        if copyWidth > 0 && copyHeight > 0 {
            let region = MTLRegionMake2D(0, 0, copyWidth, copyHeight)
            drawable.texture.replace(region: region, mipmapLevel: 0, withBytes: fb.buffer, bytesPerRow: fb.stride)
            
            if let commandBuffer = commandQueue?.makeCommandBuffer() {
                commandBuffer.present(drawable)
                commandBuffer.commit()
            }
        }
    }
    
    // MARK: - Input Handling
    
    private func sendMouse(event: NSEvent, isDown: Bool) {
        let loc = convert(event.locationInWindow, from: nil)
        // Flip Y, standard NSView coordinate mapping
        let x = UInt16(min(max(0, loc.x), bounds.width))
        let y = UInt16(min(max(0, bounds.height - loc.y), bounds.height))
        
        // FreeRDP flags: PTR_FLAGS_DOWN = 0x8000
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
        // PTR_FLAGS_MOVE
        rdp?.sendMouseInput(flags: 0x0800, x: x, y: y)
    }
    
    public override func keyDown(with event: NSEvent) {
        // Map basic macOS keycodes to RDP scancodes for spike
        let scancode = mapMacKeyCodeToRDP(event.keyCode)
        if scancode > 0 {
            let flags: UInt16 = 0x0000 // KBD_FLAGS_DOWN
            rdp?.sendKeyboardInput(flags: flags, scancode: scancode)
        }
    }
    
    public override func keyUp(with event: NSEvent) {
        let scancode = mapMacKeyCodeToRDP(event.keyCode)
        if scancode > 0 {
            let flags: UInt16 = 0x4000 // KBD_FLAGS_RELEASE
            rdp?.sendKeyboardInput(flags: flags, scancode: scancode)
        }
    }
    
    private func mapMacKeyCodeToRDP(_ macCode: UInt16) -> UInt16 {
        // Tiny subset for spike demonstration
        switch macCode {
        case 0: return 0x1E // A
        case 1: return 0x1F // S
        case 2: return 0x20 // D
        case 3: return 0x21 // F
        case 11: return 0x30 // B
        case 12: return 0x10 // Q
        case 13: return 0x11 // W
        case 14: return 0x12 // E
        case 15: return 0x13 // R
        case 17: return 0x14 // T
        case 36: return 0x1C // Return
        case 49: return 0x39 // Space
        case 51: return 0x0E // Backspace
        case 123: return 0x4B // Left (requires EXT flag normally, simplified here)
        case 124: return 0x4D // Right
        case 125: return 0x50 // Down
        case 126: return 0x48 // Up
        default: return 0 // Ignore
        }
    }
}
