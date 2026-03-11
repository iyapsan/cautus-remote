import SwiftUI
import AppKit
import CautusRDP

/// Replaces TerminalPaneView for rendering RDP sessions natively in SwiftUI.
struct RDPWorkspaceView: NSViewRepresentable {
    let session: RDPSession
    let sessionId: UUID
    let isFocused: Bool

    func makeNSView(context: Context) -> RDPMetalView {
        // Firmly decouple the rendering surface from SwiftUI's redraws
        return SessionViewCache.shared.view(for: sessionId, session: session)
    }

    func updateNSView(_ nsView: RDPMetalView, context: Context) {
        nsView.session = session
        
        // If the view becomes focused, make it the first responder
        // to intercept keystrokes via its NSView overrides.
        if isFocused {
            DispatchQueue.main.async {
                if nsView.window?.firstResponder !== nsView {
                    nsView.window?.makeFirstResponder(nsView)
                }
            }
        }
    }
}
