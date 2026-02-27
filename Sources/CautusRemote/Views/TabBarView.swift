import SwiftUI

/// Session tab bar — displays active connection tabs with status indicators.
///
/// Native-feeling tab appearance with close buttons, drag-to-reorder (future),
/// and visual emphasis on the active tab.
struct TabBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(appState.workspace.tabs) { tab in
                    TabItemView(tab: tab)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 36)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

/// Individual tab in the tab bar.
struct TabItemView: View {
    let tab: SessionTab

    @Environment(AppState.self) private var appState

    private var isActive: Bool {
        appState.workspace.activeTabId == tab.id
    }

    private var sessionState: SessionState {
        appState.sessionManager.state(for: tab.sessionId)
    }

    var body: some View {
        HStack(spacing: 6) {
            // Status dot
            Circle()
                .fill(sessionState.statusColor.color)
                .frame(width: 6, height: 6)

            Text(tab.title)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
                .foregroundStyle(isActive ? .primary : .secondary)

            // Close button
            Button {
                Task {
                    await appState.sessionManager.close(sessionId: tab.sessionId)
                }
                appState.workspace.closeTab(id: tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isActive ? 0.7 : 0.3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            if isActive {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            appState.workspace.activeTabId = tab.id
        }
    }
}
