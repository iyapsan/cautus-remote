import SwiftUI
import CautusRDP

/// Displays the active tab's terminal content.
///
/// Uses a ZStack to keep all terminal views alive — switching tabs
/// toggles visibility without destroying the NSView (which would lose
/// terminal scrollback and session state).
struct WorkspaceView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            ForEach(appState.workspace.tabs) { tab in
                if let activeSession = appState.sessionManager.sessions[tab.sessionId] {
                    SessionContainerView(
                        session: activeSession,
                        isFocused: appState.workspace.activeTabId == tab.id
                    )
                    .opacity(appState.workspace.activeTabId == tab.id ? 1 : 0)
                    .allowsHitTesting(appState.workspace.activeTabId == tab.id)
                }
            }
        }
    }
}

private struct SessionContainerView: View {
    @ObservedObject var session: RDPSession
    let isFocused: Bool
    
    var body: some View {
        ZStack {
            RDPWorkspaceView(
                session: session,
                isFocused: isFocused
            )
            
            if session.state != .connected {
                ConnectionOverlayView(session: session)
            }
        }
    }
}

private struct ConnectionOverlayView: View {
    @ObservedObject var session: RDPSession
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.4))
                .background(.ultraThinMaterial)
            
            VStack(spacing: 20) {
                // Determine icon and description
                let isError = isDisconnectedError(session.state)
                let iconName: String = isError ? "exclamationmark.triangle.fill" : "network"
                let iconColor: Color = isError ? .red : .blue
                
                Image(systemName: iconName)
                    .font(.system(size: 48))
                    .foregroundColor(iconColor)
                    .symbolEffect(.pulse, options: .repeating, isActive: session.state == .connecting || isReconnecting(session.state))
                
                Text(session.state.description)
                    .font(.title2)
                    .bold()
                
                // Show a Cancel button if we are reconnecting (or trying to connect)
                if isReconnecting(session.state) {
                    Button("Cancel Reconnect") {
                        session.disconnect()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .controlSize(.large)
                }
            }
            .padding(40)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(16)
            .shadow(radius: 20)
        }
        .ignoresSafeArea()
    }
    
    private func isDisconnectedError(_ state: RDPConnectionState) -> Bool {
        if case .disconnected(let err) = state { return err != nil }
        return false
    }
    
    private func isReconnecting(_ state: RDPConnectionState) -> Bool {
        if case .reconnecting(_, _) = state { return true }
        return false
    }
}
