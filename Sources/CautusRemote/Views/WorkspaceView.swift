import SwiftUI
import CautusRDP

/// Displays the active tab's terminal content.
///
/// Uses a ZStack to keep all terminal views alive — switching tabs
/// toggles visibility without destroying the NSView (which would lose
/// terminal scrollback and session state).
struct WorkspaceView: View {
    let sessionId: UUID
    @Environment(AppState.self) private var appState
    @Environment(SessionCoordinator.self) private var sessionCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack {
            if let activeSession = appState.sessionManager.sessions[sessionId] {
                SessionContainerView(
                    session: activeSession,
                    isFocused: true
                )
            } else {
                Text("Session Ended.")
                    .foregroundStyle(.secondary)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            ConnectionOverlayView(session: session)
                .opacity(session.state == .connected ? 0 : 1)
                .allowsHitTesting(session.state != .connected)
                .animation(.easeInOut(duration: 0.2), value: session.state)
        }
    }
}

private struct ConnectionOverlayView: View {
    @ObservedObject var session: RDPSession
    
    var body: some View {
        ZStack {
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
