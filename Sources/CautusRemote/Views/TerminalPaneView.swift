import SwiftUI

/// Displays a terminal pane for a single session.
///
/// Wraps `TerminalHostView` with session state overlay (connecting, failed, disconnected)
/// and focus ring styling.
struct TerminalPaneView: View {
    let sessionId: UUID
    let isFocused: Bool

    @Environment(AppState.self) private var appState

    private var session: SSHSession? {
        appState.sessionManager.sessions[sessionId] as? SSHSession
    }

    var body: some View {
        ZStack {
            if let session {
                switch session.state {
                case .connected:
                    TerminalHostView(
                        session: session,
                        theme: .midnight,
                        isFocused: isFocused
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))

                case .connecting:
                    connectingView

                case .reconnecting(let attempt):
                    reconnectingView(attempt: attempt)

                case .failed(let error):
                    failedView(error: error)

                case .disconnected:
                    disconnectedView

                case .idle:
                    idleView
                }
            } else {
                noSessionView
            }
        }
        .padding(6)
        .background(Color(nsColor: TerminalTheme.midnight.background))
    }

    // MARK: - State Views

    private var connectingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)
            Text("Connecting...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func reconnectingView(attempt: Int) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)
            Text("Reconnecting (attempt \(attempt)/5)...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func failedView(error: SessionError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.red.opacity(0.8))

            Text("Connection Failed")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            Text(error.message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button("Retry") {
                Task {
                    try? await session?.reconnect()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var disconnectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.6))

            Text("Disconnected")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            Button("Reconnect") {
                Task {
                    try? await session?.reconnect()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var idleView: some View {
        Text("Ready")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
    }

    private var noSessionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No active session")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}
