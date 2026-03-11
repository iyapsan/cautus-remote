import Foundation
import AppKit
import SwiftUI

@MainActor
@Observable
final class DetachedSessionWindowManager {
    private let sessionRegistry: SessionRegistry
    private var windows: [UUID: NSWindow] = [:]
    
    // Injected from app root to provide standard window content with environment bindings
    var createWindowContent: ((_ sessionID: UUID) -> AnyView)?
    
    init(sessionRegistry: SessionRegistry) {
        self.sessionRegistry = sessionRegistry
        
        self.sessionRegistry.onFocusDetached = { [weak self] windowID in
            self?.focusOrCreateWindow(windowID)
        }
        
        self.sessionRegistry.onCloseDetachedWindow = { [weak self] windowID in
            self?.closeWindow(windowID)
        }
    }
    
    private func focusOrCreateWindow(_ windowID: UUID) {
        if let existing = windows[windowID] {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        
        guard let record = sessionRegistry.activeSessions.values.first(where: {
            if case .detached(let id) = $0.presentation { return id == windowID }
            return false
        }) else { return }
        
        guard let factory = createWindowContent else {
            print("[DetachedSessionWindowManager] Error: createWindowContent factory not set.")
            return
        }
        
        let view = factory(record.id)
        let hostingController = NSHostingController(rootView: view)
        
        let newWindow = CautusDetachedWindow(contentViewController: hostingController)
        newWindow.windowContextID = windowID
        newWindow.manager = self
        newWindow.title = record.title
        
        newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        newWindow.isReleasedWhenClosed = false
        // Ensure no generic automatic tabbing injects itself here either.
        newWindow.tabbingMode = .disallowed
        
        windows[windowID] = newWindow
        newWindow.makeKeyAndOrderFront(nil)
    }
    
    private func closeWindow(_ windowID: UUID) {
        if let window = windows[windowID] {
            window.close()
            windows.removeValue(forKey: windowID)
        }
    }
    
    func windowDidCloseNative(_ windowID: UUID) {
        windows.removeValue(forKey: windowID)
        
        // Detached Window Rule: Closing a detached window closes that session by default.
        // It is NOT equivalent to moving it back to the main window.
        if let sessionID = sessionRegistry.activeSessions.values.first(where: {
            if case .detached(let id) = $0.presentation { return id == windowID }
            return false
        })?.id {
            print("[DetachedSessionWindowManager] Native X button clicked, terminating session \(sessionID)")
            sessionRegistry.closeSession(sessionID)
        }
    }
}

class CautusDetachedWindow: NSWindow, NSWindowDelegate {
    var windowContextID: UUID?
    weak var manager: DetachedSessionWindowManager?
    
    init(contentViewController: NSViewController) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.contentViewController = contentViewController
        self.delegate = self
        self.center()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let id = windowContextID {
            manager?.windowDidCloseNative(id)
        }
        return true
    }
}
