import SwiftUI
import AppKit
import CautusRDP

/// Replaces TerminalPaneView for rendering RDP sessions natively in SwiftUI.
struct RDPWorkspaceView: NSViewRepresentable {
    let session: RDPSession
    let isFocused: Bool

    func makeNSView(context: Context) -> RDPMetalView {
        let device = MTLCreateSystemDefaultDevice()
        // Initialize at a reasonable default size; MTKView auto-resizes.
        let mtkView = RDPMetalView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720), device: device)
        mtkView.session = session
        return mtkView
    }

    func updateNSView(_ nsView: RDPMetalView, context: Context) {
        nsView.session = session
        // If the view becomes focused, we should ideally make it the first responder
        // so it intercepts keystrokes via its NSView overrides.
        if isFocused {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}
