import Foundation
import AppKit
import CautusRDP

/// A singleton cache that firmly retains the `RDPMetalView` NSView instance
/// for each docked session. This completely decouples the live FreeRDP rendering
/// surface from the volatile lifecycle of SwiftUI view state, preventing
/// unexpected drops or tearing during surface transitions.
@MainActor
final class SessionViewCache {
    static let shared = SessionViewCache()
    private var views: [UUID: RDPMetalView] = [:]
    
    func view(for id: UUID, session: RDPSession) -> RDPMetalView {
        if let existing = views[id] {
            return existing
        }
        
        print("[SessionViewCache] Creating persistent RDPMetalView for \(id)")
        let device = MTLCreateSystemDefaultDevice()
        let mtkView = RDPMetalView(frame: .zero, device: device)
        mtkView.session = session
        
        // Sever layout constraints so MTKView does not push window out when drawableSize changes
        mtkView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        mtkView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        mtkView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        mtkView.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        views[id] = mtkView
        return mtkView
    }
    
    func remove(for id: UUID) {
        if views[id] != nil {
            print("[SessionViewCache] Removing cached RDPMetalView for \(id)")
            views.removeValue(forKey: id)
        }
    }
}
