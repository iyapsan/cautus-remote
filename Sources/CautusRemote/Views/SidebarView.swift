import SwiftUI
import CautusRDP

/// Sidebar with collapsible sections for organizing connections.
///
/// Sections: Favorites, All Connections (hierarchical), Tags, Recents.
/// Includes a search field at the top.
struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionRegistry.self) private var sessionRegistry
    @Environment(BrowseCoordinator.self) private var browseCoordinator
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var windowModel: MainWindowViewModel

    @State private var allowBindingUpdates = false

    var body: some View {
        @Bindable var sidebar = appState.sidebar
        @Bindable var state = appState

        let selectionBinding = Binding<Set<UUID>>(
            get: { sidebar.selectedConnectionIds },
            set: { if allowBindingUpdates { sidebar.selectedConnectionIds = $0 } }
        )
        let favExpanded = Binding<Bool>(
            get: { sidebar.isFavoritesExpanded },
            set: { if allowBindingUpdates { sidebar.isFavoritesExpanded = $0 } }
        )
        let allExpanded = Binding<Bool>(
            get: { sidebar.isAllConnectionsExpanded },
            set: { if allowBindingUpdates { sidebar.isAllConnectionsExpanded = $0 } }
        )
        let tagsExpanded = Binding<Bool>(
            get: { sidebar.isTagsExpanded },
            set: { if allowBindingUpdates { sidebar.isTagsExpanded = $0 } }
        )
        let recentsExpanded = Binding<Bool>(
            get: { sidebar.isRecentsExpanded },
            set: { if allowBindingUpdates { sidebar.isRecentsExpanded = $0 } }
        )

        VStack(spacing: 0) {
            ZStack {
                List(selection: selectionBinding) {
                    // Favorites
                    if !appState.connectionService.favorites.isEmpty {
                        Section(isExpanded: favExpanded) {
                            ForEach(appState.connectionService.favorites) { connection in
                                ConnectionRow(connection: connection)
                            }
                        } header: {
                            Label("Favorites", systemImage: "star.fill")
                        }
                        .selectionDisabled()
                    }

                    // All Connections (with folders)
                    Section(isExpanded: allExpanded) {
                        // Root folders
                        ForEach(appState.connectionService.rootFolders) { folder in
                            FolderRow(folder: folder)
                        }

                        // Unfiled connections (no folder)
                        ForEach(appState.connectionService.unfiledConnections) { connection in
                            ConnectionRow(connection: connection)
                        }
                    } header: {
                        ConnectionsSectionHeader()
                    }
                    .dropDestination(for: ConnectionTransfer.self) { transfers, _ in
                        let connectionIds = Set(appState.connectionService.allConnections.map(\.id))
                        let idsToMove = Self.idsToMove(transfers: transfers, selectedIds: appState.sidebar.selectedConnectionIds, connectionIds: connectionIds)
                        for id in idsToMove {
                            if let real = appState.connectionService.allConnections.first(where: { $0.id == id }) {
                                try? appState.connectionService.moveConnection(real, to: nil)
                            }
                        }
                        return !idsToMove.isEmpty
                    }

                    // Tags
                    if !appState.connectionService.allTags.isEmpty {
                        Section(isExpanded: tagsExpanded) {
                            ForEach(appState.connectionService.allTags) { tag in
                                TagRow(tag: tag)
                            }
                        } header: {
                            Label("Tags", systemImage: "tag.fill")
                        }
                        .selectionDisabled()
                    }

                    // Recents
                    if !appState.connectionService.recents.isEmpty {
                        Section(isExpanded: recentsExpanded) {
                            ForEach(appState.connectionService.recents) { connection in
                                ConnectionRow(connection: connection)
                            }
                        } header: {
                            Label("Recents", systemImage: "clock.fill")
                        }
                        .selectionDisabled()
                    }
                }
                .listStyle(.sidebar)
                .transaction { $0.animation = nil }
                .id(windowModel.listId)
            }
        }
        .frame(minWidth: Layout.sidebarMinWidth, maxWidth: Layout.sidebarMaxWidth)
        .onAppear {
            // Force the initial sync into windowModel. The .onChange won't fire if the initial global 
            // state matches what it was when the window opened.
            let currentSelection = appState.sidebar.selectedConnectionIds
            if let firstID = currentSelection.first {
                if appState.connectionService.allFoldersFlattened().contains(where: { $0.folder.id == firstID }) {
                    windowModel.inspectorSelection = .folder(firstID)
                    windowModel.browseContentSelection = .folder(firstID)
                    windowModel.inspectorVisible = true
                } else if appState.connectionService.allConnections.contains(where: { $0.id == firstID }) {
                    windowModel.inspectorSelection = .connection(firstID)
                    windowModel.browseContentSelection = .connection(firstID)
                    windowModel.inspectorVisible = true
                } else {
                    windowModel.inspectorSelection = .none
                    windowModel.browseContentSelection = .welcome
                }
            } else {
                windowModel.inspectorSelection = .none
                windowModel.browseContentSelection = .welcome
            }

            // Delay accepting binding overwrites to outlast the NSOutlineView 
            // initialization phase which aggressively writes generic false/empty states back.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                allowBindingUpdates = true
            }
        }
        .onChange(of: sidebar.selectedConnectionIds) { oldSelection, newSelection in
            if let firstID = newSelection.first {
                // Determine if it's a folder or connection
                if appState.connectionService.allFoldersFlattened().contains(where: { $0.folder.id == firstID }) {
                    windowModel.inspectorSelection = .folder(firstID)
                    windowModel.browseContentSelection = .folder(firstID)
                    windowModel.inspectorVisible = true
                } else if appState.connectionService.allConnections.contains(where: { $0.id == firstID }) {
                    windowModel.inspectorSelection = .connection(firstID)
                    windowModel.browseContentSelection = .connection(firstID)
                    windowModel.inspectorVisible = true
                } else {
                    windowModel.inspectorSelection = .none
                    windowModel.browseContentSelection = .welcome
                }
            } else {
                windowModel.inspectorSelection = .none
                windowModel.browseContentSelection = .welcome
            }
        }
        .background {
            SidebarDoubleClickMonitor(appState: appState) { connection in
                openSessionTab(for: connection)
            }
        }
        // New folder alert
        .alert("New Folder", isPresented: $state.isShowingNewFolderAlert) {
            TextField("Folder name", text: $state.folderAlertText)
            Button("Create") {
                let name = appState.folderAlertText.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                if let created = try? appState.connectionService.createFolder(
                    name: name,
                    parent: appState.folderActionTarget
                ) {
                    appState.sidebar.selectedConnectionIds = [created.id]
                    windowModel.browseContentSelection = .folder(created.id)
                    windowModel.inspectorVisible = true
                    windowModel.inspectorSelection = .folder(created.id)
                }
                appState.folderActionTarget = nil
            }
            Button("Cancel", role: .cancel) {
                appState.folderActionTarget = nil
            }
        } message: {
            if let parent = appState.folderActionTarget {
                Text("Create a subfolder in \"\(parent.name)\"")
            } else {
                Text("Create a new root folder")
            }
        }
        // Rename folder alert
        .alert("Rename Folder", isPresented: $state.isShowingRenameFolderAlert) {
            TextField("Folder name", text: $state.folderAlertText)
            Button("Rename") {
                let name = appState.folderAlertText.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, let folder = appState.folderActionTarget else { return }
                folder.name = name
                try? appState.connectionService.saveFolder(folder)
                appState.folderActionTarget = nil
            }
            Button("Cancel", role: .cancel) {
                appState.folderActionTarget = nil
            }
        }
        // Global Defaults sheet — hoisted here so it's always in the view hierarchy.
        // Do NOT put this inside a List section header; sheet modifiers are unreliable there.
        .sheet(isPresented: $state.isShowingGlobalDefaultsSheet) {
            GlobalDefaultsSheetView()
        }
    }

    /// Merge dragged transfer IDs with the current multi-selection.
    /// If the dragged item is part of the selection, move ALL selected connections.
    /// Filters out non-connection IDs (e.g., folder IDs that may be in the selection).
    static func idsToMove(transfers: [ConnectionTransfer], selectedIds: Set<UUID>, connectionIds: Set<UUID>) -> Set<UUID> {
        let draggedIds = Set(transfers.map(\.id))
        let ids: Set<UUID>
        if !draggedIds.isDisjoint(with: selectedIds) {
            ids = selectedIds.union(draggedIds)
        } else {
            ids = draggedIds
        }
        return ids.intersection(connectionIds)
    }

    private func openSessionTab(for connection: Connection) {
        sessionRegistry.openSession(for: connection)
    }
}

// MARK: - Double-Click Monitor

struct SidebarDoubleClickMonitor: NSViewRepresentable {
    let appState: AppState
    let onDoubleClick: (Connection) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = MonitorView()
        view.appState = appState
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class MonitorView: NSView {
        var appState: AppState?
        var onDoubleClick: ((Connection) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                    guard let self = self else { return event }
                    if event.clickCount == 2 {
                        let pointInWindow = event.locationInWindow
                        let pointInView = self.convert(pointInWindow, from: nil)
                        if self.bounds.contains(pointInView) {
                            self.handleDoubleClick()
                        }
                    }
                    return event // Always pass through
                }
            }
        }

        private func handleDoubleClick() {
            guard let appState,
                  let selectedId = appState.sidebar.selectedConnectionIds.first,
                  let connection = appState.connectionService.allConnections.first(where: { $0.id == selectedId })
            else { return }

            NSLog("[SidebarDoubleClickMonitor] user double clicked %@", connection.name)
            onDoubleClick?(connection)
        }

        override func removeFromSuperview() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            super.removeFromSuperview()
        }
    }
}

// MARK: - Row Views

/// Single connection row in the sidebar.
struct ConnectionRow: View {
    let connection: Connection

    @Environment(AppState.self) private var appState
    @Environment(SessionRegistry.self) private var sessionRegistry
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var windowModel: MainWindowViewModel

    // Determine the status of this connection based on active sessions
    private var sessionState: RDPConnectionState {
        guard let record = sessionRegistry.existingLiveSession(for: connection.id),
              let runtime = sessionRegistry.runtime(for: record.id) else {
            return .idle
        }
        return runtime.state
    }

    private var statusColor: Color {
        switch sessionState {
        case .connected: return .green
        case .reconnecting(_, _): return .yellow
        case .disconnected(.some): return .red
        default: return .clear
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: Layout.statusDotSize, height: Layout.statusDotSize)

            VStack(alignment: .leading, spacing: 1) {
                Text(connection.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(connection.displayAddress)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if connection.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow.opacity(0.7))
            }
        }
        .frame(height: Layout.sidebarRowHeight)
        .contentShape(Rectangle())
        .draggable(ConnectionTransfer(id: connection.id)) {
            // Count only actual connections in the selection (exclude folders, duplicates from Recents/Favorites)
            let selectedIds = appState.sidebar.selectedConnectionIds
            let connectionIds = Set(appState.connectionService.allConnections.map(\.id))
            let selectedConnectionCount = selectedIds.intersection(connectionIds).count
            let count = selectedIds.contains(connection.id) ? selectedConnectionCount : 1
            if count > 1 {
                Label("\(count) connections", systemImage: "rectangle.stack")
                    .padding(8)
            } else {
                Text(connection.name)
                    .padding(8)
            }
        }
        .contextMenu {
            // Move to folder submenu
            Menu("Move to Folder") {
                let folders = appState.connectionService.allFoldersFlattened()
                if !folders.isEmpty {
                    Button("No Folder") {
                        try? appState.connectionService.moveConnection(connection, to: nil)
                    }
                    Divider()
                    ForEach(folders, id: \.folder.id) { item in
                        Button(String(repeating: "  ", count: item.depth) + item.folder.name) {
                            try? appState.connectionService.moveConnection(connection, to: item.folder)
                        }
                    }
                    Divider()
                }
                Button {
                    appState.folderActionTarget = nil
                    appState.folderAlertText = ""
                    appState.isShowingNewFolderAlert = true
                } label: {
                    Label("New Folder...", systemImage: "folder.badge.plus")
                }
            }

            Divider()
            Button(connection.isFavorite ? "Unfavorite" : "Favorite") {
                try? appState.connectionService.toggleFavorite(connection)
            }
            Divider()
            Button("Delete", role: .destructive) {
                try? appState.connectionService.delete(connection)
            }
        }
    }

    private func openConnection(_ connection: Connection) {
        sessionRegistry.openSession(for: connection)
    }
}

/// Folder row with disclosure group for subfolders/connections.
///
/// Uses `connectionService.connectionsInFolder()` instead of `folder.connections`
/// to ensure the view re-renders when `allConnections` changes (SwiftData's
/// inverse relationship doesn't reliably trigger SwiftUI observation updates).
struct FolderRow: View {
    let folder: Folder

    @Environment(AppState.self) private var appState
    @State private var allowBindingUpdates = false

    var body: some View {
        // Access dataVersion to register observation dependency — when loadAll()
        // runs, SwiftUI will re-evaluate this body without destroying the view
        let _ = appState.connectionService.dataVersion
        
        let isExpanded = Binding<Bool>(
            get: { appState.sidebar.expandedFolderIds.contains(folder.id) },
            set: { newValue in
                if allowBindingUpdates {
                    if newValue {
                        appState.sidebar.expandedFolderIds.insert(folder.id)
                    } else {
                        appState.sidebar.expandedFolderIds.remove(folder.id)
                    }
                }
            }
        )

        DisclosureGroup(isExpanded: isExpanded) {
            // Subfolders
            ForEach(folder.subfolders.sorted(by: { $0.sortOrder < $1.sortOrder })) { subfolder in
                FolderRow(folder: subfolder)
            }
            // Connections in this folder — use filtered allConnections for reliable refresh
            ForEach(appState.connectionService.connectionsInFolder(folder)) { connection in
                ConnectionRow(connection: connection)
            }
        } label: {
            Label {
                Text(folder.name)
                    .font(.system(size: 12, weight: .medium))
            } icon: {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.secondary)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    allowBindingUpdates = true
                }
            }
            .contextMenu {
                Button {
                    appState.folderActionTarget = folder
                    appState.folderAlertText = ""
                    appState.isShowingNewFolderAlert = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                Menu("New Connection") {
                    Button("New RDP Connection") {
                        appState.connectionCreationParentFolderId = folder.id
                        appState.editingConnection = nil
                        appState.isShowingConnectionSheet = true
                    }
                    Button("New VNC Connection") { }
                        .disabled(true)
                    Button("New SSH Connection") { }
                        .disabled(true)
                }
                Divider()
                Button("Rename") {
                    appState.folderActionTarget = folder
                    appState.folderAlertText = folder.name
                    appState.isShowingRenameFolderAlert = true
                }
                Button("Delete", role: .destructive) {
                    try? appState.connectionService.deleteFolder(folder)
                }
            }
        }
        .dropDestination(for: ConnectionTransfer.self) { transfers, _ in
            let connectionIds = Set(appState.connectionService.allConnections.map(\.id))
            let idsToMove = SidebarView.idsToMove(transfers: transfers, selectedIds: appState.sidebar.selectedConnectionIds, connectionIds: connectionIds)
            for id in idsToMove {
                if let real = appState.connectionService.allConnections.first(where: { $0.id == id }) {
                    try? appState.connectionService.moveConnection(real, to: folder)
                }
            }
            return !idsToMove.isEmpty
        }
    }
}

// MARK: - Search Results

/// Separate List for search results — avoids NSOutlineView crash from
/// swapping structural content in the main sidebar List.
struct SearchResultsView: View {
    let query: String

    @Environment(AppState.self) private var appState

    private var results: [Connection] {
        let q = query.lowercased()
        return appState.connectionService.allConnections.filter {
            $0.name.lowercased().contains(q)
            || $0.host.lowercased().contains(q)
            || $0.username.lowercased().contains(q)
        }
    }

    var body: some View {
        List {
            Section("Results (\(results.count))") {
                ForEach(results) { connection in
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(connection.name)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                Text(connection.displayAddress)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                if let folder = connection.folder {
                                    Text("• \(folder.name)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .lineLimit(1)
                        }
                    }
                    .frame(height: Layout.sidebarRowHeight)
                    .contentShape(Rectangle())
                }
            }
        }
        .listStyle(.sidebar)
    }
}

/// Tag row showing name and connection count.
struct TagRow: View {
    let tag: Tag

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: tag.colorHex) ?? .gray)
                .frame(width: 8, height: 8)
            Text(tag.name)
                .font(.system(size: 12))
            Spacer()
            Text("\(tag.connections.count)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Color Hex Extension


extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        guard hex.count == 6,
              let int = UInt64(hex, radix: 16) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Connections Section Header

/// Section header for "Connections".
private struct ConnectionsSectionHeader: View {
    var body: some View {
        Label("Connections", systemImage: "server.rack")
    }
}


