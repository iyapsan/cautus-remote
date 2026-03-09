import SwiftUI

/// Root view for the application — single-window layout.
///
/// Uses `NavigationSplitView` for the sidebar + detail pattern.
/// Toolbar contains sidebar toggle, command palette trigger, and new connection button.
struct MainWindowView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var windowModel = MainWindowViewModel()

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView(
            columnVisibility: $appState.sidebar.columnVisibility
        ) {
            SidebarView()
        } detail: {
            HStack(spacing: 0) {
                MainContentRootView()
                    .environmentObject(windowModel)
                    .background(Color(NSColor.controlBackgroundColor))
                
                if windowModel.inspectorVisible {
                    Divider()
                    InspectorRootView()
                        .frame(width: 320)
                        .background(Color(NSColor.windowBackgroundColor))
                }
            }
        }
        .environmentObject(windowModel)
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search", text: $windowModel.browserSearchQuery)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 160)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    windowModel.inspectorVisible.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .help(windowModel.inspectorVisible ? "Hide Inspector" : "Show Inspector")

                Button {
                    appState.palette.show()
                } label: {
                    Image(systemName: "command")
                        .symbolRenderingMode(.hierarchical)
                }
                .keyboardShortcut("k", modifiers: .command)
                .help("Command Palette (⌘K)")

                Menu {
                    Button("New Folder") {
                        appState.folderActionTarget = appState.selectedFolderForCreation
                        appState.folderAlertText = ""
                        appState.isShowingNewFolderAlert = true
                    }
                    Divider()
                    Button("New RDP Connection") {
                        appState.connectionCreationParentFolderId = nil
                        appState.editingConnection = nil
                        appState.isShowingConnectionSheet = true
                    }
                    Button("New VNC Connection") { }
                        .disabled(true)
                    Button("New SSH Connection") { }
                        .disabled(true)
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("New (⌘N)")

                if shouldShowToolbarDisconnect, let activeTab = appState.workspace.activeTab {
                    Button {
                        Task { await disconnect(tab: activeTab) }
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .help("Disconnect")
                }
            }
        }
        .sheet(isPresented: $appState.isShowingConnectionSheet, onDismiss: {
            try? appState.connectionService.loadAll()
            if let id = appState.newlyCreatedConnectionId {
                appState.sidebar.selectedConnectionIds = [id]
                windowModel.browserSelection = .connection(id)
                appState.workspace.activeTabId = nil
                windowModel.inspectorVisible = true
                windowModel.inspectorSelection = .connection(id)
                appState.newlyCreatedConnectionId = nil
            }
            appState.connectionCreationParentFolderId = nil
        }) {
            ConnectionSheetView()
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
        .onChange(of: windowModel.browserSearchQuery) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                // Restore sidebar-driven state
                let selectedIds = appState.sidebar.selectedConnectionIds
                if let firstID = selectedIds.first {
                    if appState.connectionService.allFoldersFlattened().contains(where: { $0.folder.id == firstID }) {
                        windowModel.browserSelection = .folder(firstID)
                    } else if appState.connectionService.allConnections.contains(where: { $0.id == firstID }) {
                        windowModel.browserSelection = .connection(firstID)
                    } else {
                        windowModel.browserSelection = .welcome
                    }
                } else {
                    windowModel.browserSelection = .welcome
                }
            } else {
                windowModel.browserSelection = .search(trimmed)
                appState.workspace.activeTabId = nil
            }
        }
    }

    private var shouldShowToolbarDisconnect: Bool {
        guard !windowModel.inspectorVisible, let tab = appState.workspace.activeTab else { return false }
        switch appState.sessionManager.state(for: tab.sessionId) {
        case .connected, .connecting, .reconnecting(_, _):
            return true
        case .idle, .disconnected:
            return false
        }
    }

    private func disconnect(tab: SessionTab) async {
        await appState.sessionManager.close(sessionId: tab.sessionId)
        appState.workspace.closeTab(id: tab.id)
    }
}
