import SwiftUI
import AppKit

/// Root view for the application — single-window command center layout.
///
/// Uses `NavigationSplitView` for the sidebar + detail pattern.
/// The detail area uses a `ZStack` to safely switch between the permanent `Browse` 
/// surface and multiple `Docked Sessions` without destroying their live Metal contexts.
struct MainWindowView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionRegistry.self) private var sessionRegistry
    @Environment(BrowseCoordinator.self) private var browseCoordinator
    
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
                
                // HARD ACCEPTANCE GATE:
                // ZStack preserves RDPMetalView context perfectly. 
                // Only opacity and hit testing toggle visibility for the active surface.
                VStack(spacing: 0) {
                    DockedSessionSwitcherView()

                    ZStack {
                        MainContentRootView()
                            .environmentObject(windowModel)
                            .navigationTitle(titleForCurrentSurface())
                            .opacity(browseCoordinator.selectedSurface == .browse ? 1.0 : 0.0)
                            .allowsHitTesting(browseCoordinator.selectedSurface == .browse)
                        
                        ForEach(browseCoordinator.dockedSessionIDs, id: \.self) { sessionID in
                            let isSelected = browseCoordinator.selectedSurface == .dockedSession(sessionID)
                            WorkspaceView(sessionId: sessionID, isFocused: isSelected)
                                .opacity(isSelected ? 1.0 : 0.0)
                                .allowsHitTesting(isSelected)
                        }
                    }
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
        .toolbar { toolbarContent }



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
                windowModel.browseContentSelection = .search(trimmed)
            }
        }
        .onChange(of: appState.sidebar.selectedConnectionIds) { oldSelection, newSelection in
            print("[MainWindowView] Selection changed from \(oldSelection) to \(newSelection)")
        }
        // These observers route custom global actions triggered by the Menu or shortcuts
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CautusShowConnectionSheet"))) { _ in
            appState.connectionCreationParentFolderId = nil
            appState.editingConnection = nil
            appState.isShowingConnectionSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CautusCreateNewFolder"))) { _ in
            appState.folderActionTarget = appState.selectedFolderForCreation
            appState.folderAlertText = ""
            appState.isShowingNewFolderAlert = true
        }
        .background {
            // ⌃Tab and ⇧⌃Tab are swallowed by macOS before SwiftUI Commands
            // can receive them. Use a local NSEvent monitor to reliably intercept.
            TabNavigationMonitor(browseCoordinator: browseCoordinator)
        }
    }
    
    private func titleForCurrentSurface() -> String {
        let suffix: String
        switch browseCoordinator.selectedSurface {
        case .browse:
            suffix = "Browse"
        case .dockedSession(let id):
            suffix = sessionRegistry.session(for: id)?.title ?? "Session"
        }
        return "Cautus Remote — \(suffix)"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Search
        ToolbarItem(placement: .automatic) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $windowModel.browserSearchQuery)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.regular)
                    .frame(minWidth: 160)
            }
            .padding(.leading, 8)
        }

        // [+ New][⌘ Palette][≡ Defaults] — ONE ToolbarItem = one NSToolbarItem
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 2) {
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
                    Button("New VNC Connection") { }.disabled(true)
                    Button("New SSH Connection") { }.disabled(true)
                } label: {
                    Label("New", systemImage: "plus")
                }
                .help("New (⌘N)")

                Button {
                    appState.palette.show()
                } label: {
                    Label("Command Palette", systemImage: "command")
                        .symbolRenderingMode(.hierarchical)
                }
                .keyboardShortcut("k", modifiers: .command)
                .help("Command Palette (⌘K)")

                Button {
                    windowModel.inspectorVisible   = true
                    windowModel.inspectorSelection = .globalDefaults
                    windowModel.browseContentSelection = .welcome
                } label: {
                    Label("Edit Defaults", systemImage: "slider.horizontal.3")
                }
                .help("Edit Global Defaults")
            }
        }

        // [Inspector] — separate ToolbarItem for natural macOS toolbar spacing
        ToolbarItem(placement: .primaryAction) {
            Button {
                windowModel.inspectorVisible.toggle()
            } label: {
                Label(
                    windowModel.inspectorVisible ? "Hide Inspector" : "Show Inspector",
                    systemImage: "sidebar.right"
                )
            }
            .help(windowModel.inspectorVisible ? "Hide Inspector" : "Show Inspector")
        }
    }
}
