import SwiftUI

/// Root view for the application — single-window layout.
///
/// Uses `NavigationSplitView` for the sidebar + detail pattern.
/// Toolbar contains sidebar toggle, command palette trigger, and new connection button.
struct MainWindowView: View {
    let tabKind: WindowTabKind

    @Environment(AppState.self) private var appState
    @Environment(SessionCoordinator.self) private var sessionCoordinator
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowModel = MainWindowViewModel()

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView(
            columnVisibility: $appState.sidebar.columnVisibility
        ) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 400)
        } detail: {
            HStack(spacing: 0) {
                switch tabKind {
                case .browse:
                    MainContentRootView()
                        .environmentObject(windowModel)
                case .session(let sessionId):
                    WorkspaceView(sessionId: sessionId)
                }
                
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
            }
        }
        .sheet(isPresented: $appState.isShowingConnectionSheet, onDismiss: {
            try? appState.connectionService.loadAll()
            if let id = appState.newlyCreatedConnectionId {
                appState.sidebar.selectedConnectionIds = [id]
                windowModel.browseContentSelection = .connection(id)
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
            idealWidth: 1200,
            maxWidth: .infinity,
            minHeight: Layout.minWindowHeight,
            idealHeight: 800,
            maxHeight: .infinity
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
                        windowModel.browseContentSelection = .folder(firstID)
                    } else if appState.connectionService.allConnections.contains(where: { $0.id == firstID }) {
                        windowModel.browseContentSelection = .connection(firstID)
                    } else {
                        windowModel.browseContentSelection = .welcome
                    }
                } else {
                    windowModel.browseContentSelection = .welcome
                }
            } else {
                windowModel.browseContentSelection = .emptyState
            }
        }
        .onChange(of: appState.sidebar.selectedConnectionIds) { oldSelection, newSelection in
            print("[MainWindowView] Selection changed from \(oldSelection) to \(newSelection)")
        }
        .background(WindowTabbingConfigurator(tabKind: tabKind, coordinator: sessionCoordinator))
        .onAppear {
            sessionCoordinator.defaultOpenWindowAction = openWindow
        }
    }

// MARK: - Native Window Tabbing Configurator
struct WindowTabbingConfigurator: NSViewRepresentable {
    let tabKind: WindowTabKind
    let coordinator: SessionCoordinator
    
    func makeNSView(context: Context) -> NSView {
        let view = TabbingConfigView()
        view.tabKind = tabKind
        view.coordinator = coordinator
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class TabbingConfigView: NSView {
    var tabKind: WindowTabKind?
    var coordinator: SessionCoordinator?
    private var closeObserver: Any?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = self.window, let tabKind = tabKind else { return }
        
        if closeObserver == nil {
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak coordinator] _ in
                Task { @MainActor in
                    if case .session(let sessionId) = tabKind {
                        coordinator?.sessionDidClose(sessionId: sessionId, openWindow: coordinator?.defaultOpenWindowAction)
                    } else if case .browse = tabKind {
                        coordinator?.browseDidClose()
                    }
                }
            }
        }
        
        // Mark this window with our specific tabbing identifier
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "CautusRemoteMainTabGroup"
        NSWindow.allowsAutomaticWindowTabbing = false
        
        // Register window with coordinator
        if case .session(let sessionId) = tabKind {
            coordinator?.registerWindow(for: sessionId, window: window)
        } else if case .browse = tabKind {
            coordinator?.browseTabWindow = window
        }
        
        // Set the window title
        if case .session(let sessionId) = tabKind {
            // Coordinator knows best how to disambiguate the title
            if let connId = coordinator?.sessionIDByConnectionID.first(where: { $0.value == sessionId })?.key,
               let connection = coordinator?.appState.connectionService.connection(connId) {
                window.title = coordinator?.title(for: connection) ?? connection.name
            }
        } else {
            window.title = "Browse"
        }
        
        // Find any other existing window with the same identifier
        if let existingWindow = NSApp.windows.first(where: { 
            $0 != window && $0.tabbingIdentifier == "CautusRemoteMainTabGroup" && $0.isVisible 
        }) {
            // If this window isn't already tabbed with the existing one, force attach it
            if existingWindow.tabbedWindows?.contains(window) != true {
                existingWindow.addTabbedWindow(window, ordered: .above)
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
}
