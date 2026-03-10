import SwiftUI
import AppKit
import CautusRDP

/// Replaces TerminalPaneView for rendering RDP sessions natively in SwiftUI.
struct RDPWorkspaceView: NSViewRepresentable {
    let session: RDPSession
    let isFocused: Bool

    func makeNSView(context: Context) -> RDPMetalView {
        let device = MTLCreateSystemDefaultDevice()
        let mtkView = RDPMetalView(frame: .zero, device: device)
        mtkView.session = session
        
        // Sever layout constraints so MTKView does not push window out when drawableSize changes
        mtkView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        mtkView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        mtkView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        mtkView.setContentHuggingPriority(.defaultLow, for: .vertical)
        
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
