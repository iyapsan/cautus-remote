import Foundation
import SwiftUI
import AppKit
import SwiftData
import CautusRDP

/// Coordinates native macOS sessions, their windows, and connection errors.
@MainActor
@Observable
final class SessionCoordinator {
    let appState: AppState
    let modelContainer: ModelContainer
    
    // Explicit mappings
    private(set) var sessionIDByConnectionID: [UUID: UUID] = [:]
    private(set) var sessionWindowsBySessionID: [UUID: NSWindow] = [:]
    
    var browseTabWindow: NSWindow?
    var selectedTabKind: WindowTabKind = .browse
    
    // To aid in generic tab resurrection tasks:
    @MainActor public var defaultOpenWindowAction: OpenWindowAction?
    
    init(appState: AppState, modelContainer: ModelContainer) {
        self.appState = appState
        self.modelContainer = modelContainer
    }
    
    /// Opens or focuses a native macOS session tab for the given Connection.
    /// - Parameters:
    ///   - connection: The data model connection to open
    ///   - openWindow: The SwiftUI environment action
    func openSession(for connection: Connection, openWindow: OpenWindowAction) {
        // 1. Check if we already have an active session for this connection.
        if let existingSessionID = sessionIDByConnectionID[connection.id] {
            // Stale Window Validation: Validate that the NSWindow still exists.
            if let existingWindow = sessionWindowsBySessionID[existingSessionID], existingWindow.isVisible {
                // It exists and is valid. Focus it natively.
                print("[SessionCoordinator] Focusing existing window for connection \(connection.name)")
                existingWindow.makeKeyAndOrderFront(nil)
                selectedTabKind = .session(existingSessionID)
                return
            } else {
                // Window is stale or dead. Clean up mappings and proceed to reopen.
                print("[SessionCoordinator] Stale window detected for session \(existingSessionID). Cleaning up.")
                sessionWindowsBySessionID.removeValue(forKey: existingSessionID)
                sessionIDByConnectionID.removeValue(forKey: connection.id)
                Task {
                    await appState.sessionManager.close(sessionId: existingSessionID)
                }
            }
        }
        
        // 2. Open the Session via the SessionManager (synchronously creates placeholder)
        let sessionId = appState.sessionManager.open(connection: connection)
        
        // 3. Register Identity Mappings
        sessionIDByConnectionID[connection.id] = sessionId
        try? appState.connectionService.markConnected(connection)
        
        // 4. Trigger SwiftUI to spawn the native window body manually
        let rootView = MainWindowView(tabKind: .session(sessionId))
            .environment(appState)
            .environment(self)
            .modelContainer(modelContainer)
        
        let hostingController = NSHostingController(rootView: rootView)
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        
        newWindow.tabbingMode = .preferred
        newWindow.tabbingIdentifier = "CautusRemoteMainTabGroup"
        newWindow.title = title(for: connection)
        
        // Match geometry and inject perfectly into the tab bar
        if let existingWindow = NSApp.windows.first(where: { $0.tabbingIdentifier == "CautusRemoteMainTabGroup" && $0.isVisible && $0 != newWindow }) {
            // Do NOT explicitly set the frame if the window might be zoomed or full screen,
            // otherwise macOS assumes we want to forcefully un-zoom the parent window bounds.
            // Native addTabbedWindow automatically absorbs the new window into the parent's current frame layout.
            existingWindow.addTabbedWindow(newWindow, ordered: .above)
            newWindow.makeKeyAndOrderFront(nil as Any?)
        } else {
            newWindow.makeKeyAndOrderFront(nil as Any?)
        }
        
        registerWindow(for: sessionId, window: newWindow)
    }
    
    public func openBrowse(openWindow: OpenWindowAction) {
        if let window = browseTabWindow, NSApp.windows.contains(window) {
            // Valid existing window
            print("[SessionCoordinator] Focusing existing Browse window")
            window.makeKeyAndOrderFront(nil)
            selectedTabKind = .browse
        } else {
            // Stale or dead, clear reference and recreate
            print("[SessionCoordinator] Recreating Browse window")
            browseTabWindow = nil
            openWindow(id: "main", value: WindowTabKind.browse)
        }
    }
    
    public func registerWindow(for sessionId: UUID, window: NSWindow) {
        sessionWindowsBySessionID[sessionId] = window
    }
    
    // MARK: - Teardown
    
    func sessionDidClose(sessionId: UUID, openWindow: OpenWindowAction? = nil) {
        print("[SessionCoordinator] sessionDidClose invoked for session \(sessionId). This will cancel any active connections.")
        // Find connection
        let connId = sessionIDByConnectionID.first(where: { $0.value == sessionId })?.key
        
        sessionWindowsBySessionID.removeValue(forKey: sessionId)
        if let connId = connId {
            sessionIDByConnectionID.removeValue(forKey: connId)
        }
        
        Task {
            await appState.sessionManager.close(sessionId: sessionId)
        }
        
        // Teardown flow resurrection check
        if sessionWindowsBySessionID.isEmpty, let openAction = openWindow {
            openBrowse(openWindow: openAction)
        }
    }
    
    func browseDidClose() {
        browseTabWindow = nil
    }
    
    /// Title Disambiguation Rule
    func title(for connection: Connection) -> String {
        // Find if any other active session has the exact same name
        let duplicateExists = sessionIDByConnectionID.keys.contains { otherConnId in
            if otherConnId == connection.id { return false }
            return appState.connectionService.connection(otherConnId)?.name == connection.name
        }
        
        if duplicateExists {
            return "\(connection.name) — \(connection.host)"
        } else {
            return connection.name
        }
    }
}
