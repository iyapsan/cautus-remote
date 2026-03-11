import SwiftUI
import AppKit

/// An invisible NSView that installs a local NSEvent key monitor to intercept
/// ⌃Tab (Next Tab) and ⇧⌃Tab (Previous Tab) before macOS routes them to
/// the system window-switcher, where SwiftUI Commands cannot reach them.
struct TabNavigationMonitor: NSViewRepresentable {
    let browseCoordinator: BrowseCoordinator
    
    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.browseCoordinator = browseCoordinator
        return view
    }
    
    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.browseCoordinator = browseCoordinator
    }
    
    class MonitorView: NSView {
        var browseCoordinator: BrowseCoordinator?
        private var monitor: Any?
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else {
                if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
                return
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let bc = self.browseCoordinator else { return event }
                // ⌃Tab = keyCode 48, modifier .control (without .shift)
                guard event.keyCode == 48,
                      event.modifierFlags.contains(.control) else { return event }
                
                if event.modifierFlags.contains(.shift) {
                    bc.selectPreviousSurface()
                } else {
                    bc.selectNextSurface()
                }
                return nil // consume the event
            }
        }
        
        override func removeFromSuperview() {
            if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
            super.removeFromSuperview()
        }
    }
}
