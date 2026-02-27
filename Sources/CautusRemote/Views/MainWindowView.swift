import SwiftUI

/// Root view for the application — single-window layout.
///
/// Uses `NavigationSplitView` for the sidebar + detail pattern.
/// Toolbar contains sidebar toggle, command palette trigger, and new connection button.
struct MainWindowView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView(
            columnVisibility: $appState.sidebar.columnVisibility
        ) {
            SidebarView()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            appState.folderActionTarget = nil
                            appState.folderAlertText = ""
                            appState.isShowingNewFolderAlert = true
                        } label: {
                            Image(systemName: "folder.badge.plus")
                        }
                        .help("New Folder")
                    }
                }
        } detail: {
            VStack(spacing: 0) {
                if !appState.workspace.isEmpty {
                    TabBarView()
                    WorkspaceView()
                } else {
                    EmptyStateView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    appState.palette.show()
                } label: {
                    Image(systemName: "command")
                        .symbolRenderingMode(.hierarchical)
                }
                .keyboardShortcut("k", modifiers: .command)
                .help("Command Palette (⌘K)")

                Button {
                    appState.editingConnection = nil
                    appState.isShowingConnectionSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("New Connection (⌘N)")
            }
        }
        .sheet(isPresented: $appState.isShowingConnectionSheet, onDismiss: {
            try? appState.connectionService.loadAll()
        }) {
            ConnectionFormView(
                connection: appState.editingConnection,
                initialFolderId: appState.selectedFolderIdForNewConnection
            )
        }
        .overlay(alignment: .top) {
            if appState.palette.isVisible {
                CommandPaletteView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Layout.defaultAnimation, value: appState.palette.isVisible)
        .toastContainer()
        .frame(
            minWidth: Layout.minWindowWidth,
            minHeight: Layout.minWindowHeight
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cautus Remote Main Window")
    }
}
