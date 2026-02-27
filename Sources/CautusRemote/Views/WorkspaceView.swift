import SwiftUI

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
                TerminalPaneView(
                    sessionId: tab.sessionId,
                    isFocused: appState.workspace.activeTabId == tab.id
                )
                .opacity(appState.workspace.activeTabId == tab.id ? 1 : 0)
                .allowsHitTesting(appState.workspace.activeTabId == tab.id)
            }
        }
    }
}
