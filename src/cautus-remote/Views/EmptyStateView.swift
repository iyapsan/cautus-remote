import SwiftUI

/// First-launch empty state — shown when no connections are open.
///
/// Provides a welcoming experience with quick-start actions.
struct EmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon / logo
            VStack(spacing: 16) {
                Image(systemName: "terminal")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.secondary.opacity(0.3))

                VStack(spacing: 6) {
                    Text("Cautus Remote")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("SSH Connection Manager")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            // Quick actions
            VStack(spacing: 12) {
                EmptyStateButton(
                    title: "New Connection",
                    subtitle: "Add an SSH server",
                    icon: "plus.circle.fill",
                    shortcut: "⌘N"
                ) {
                    appState.editingConnection = nil
                    appState.isShowingConnectionSheet = true
                }

                EmptyStateButton(
                    title: "Command Palette",
                    subtitle: "Search and navigate",
                    icon: "command.circle.fill",
                    shortcut: "⌘K"
                ) {
                    appState.palette.show()
                }
            }
            .frame(maxWidth: 280)

            Spacer()

            // Keyboard hint
            Text("Press ⌘N to get started")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// Styled button for the empty state screen.
struct EmptyStateButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let shortcut: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.blue.opacity(0.8))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(shortcut)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.quaternary, lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(isHovered ? 0.08 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary.opacity(0.6), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
