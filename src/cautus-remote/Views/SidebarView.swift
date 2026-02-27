import SwiftUI

/// Sidebar with collapsible sections for organizing connections.
///
/// Sections: Favorites, All Connections (hierarchical), Tags, Recents.
/// Includes a search field at the top.
struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var sidebar = appState.sidebar
        @Bindable var state = appState

        let isSearching = !sidebar.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty

        VStack(spacing: 0) {
            // Search field — always visible
            TextField("Search connections...", text: $sidebar.searchQuery)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

            ZStack {
                // Main tree view — always rendered (stable structure for NSOutlineView)
                List(selection: $sidebar.selectedConnectionIds) {
                    // Favorites
                    if !appState.connectionService.favorites.isEmpty {
                        Section(isExpanded: $sidebar.isFavoritesExpanded) {
                            ForEach(appState.connectionService.favorites) { connection in
                                ConnectionRow(connection: connection)
                            }
                        } header: {
                            Label("Favorites", systemImage: "star.fill")
                        }
                        .selectionDisabled()
                    }

                    // All Connections (with folders)
                    Section(isExpanded: $sidebar.isAllConnectionsExpanded) {
                        // Root folders
                        ForEach(appState.connectionService.rootFolders) { folder in
                            FolderRow(folder: folder)
                        }

                        // Unfiled connections (no folder)
                        ForEach(appState.connectionService.unfiledConnections) { connection in
                            ConnectionRow(connection: connection)
                        }
                    } header: {
                        Label("Connections", systemImage: "server.rack")
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
                        Section(isExpanded: $sidebar.isTagsExpanded) {
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
                        Section(isExpanded: $sidebar.isRecentsExpanded) {
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
                .opacity(isSearching ? 0 : 1)

                // Search results overlay
                if isSearching {
                    SearchResultsView(query: sidebar.searchQuery)
                }
            }
        }
        .frame(minWidth: Layout.sidebarMinWidth, maxWidth: Layout.sidebarMaxWidth)
        // Double-click to connect: single event monitor checks selected connection
        .background {
            SidebarDoubleClickMonitor(appState: appState)
        }
        // New folder alert
        .alert("New Folder", isPresented: $state.isShowingNewFolderAlert) {
            TextField("Folder name", text: $state.folderAlertText)
            Button("Create") {
                let name = appState.folderAlertText.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                try? appState.connectionService.createFolder(
                    name: name,
                    parent: appState.folderActionTarget
                )
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
}

// MARK: - Double-Click Monitor

/// Single AppKit event monitor that detects double-clicks on the sidebar
/// and connects to the currently selected connection.
struct SidebarDoubleClickMonitor: NSViewRepresentable {
    let appState: AppState

    func makeNSView(context: Context) -> NSView {
        let view = MonitorView()
        view.appState = appState
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class MonitorView: NSView {
        var appState: AppState?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                    if event.clickCount == 2 {
                        self?.handleDoubleClick()
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

            Task { @MainActor in
                do {
                    let sessionId = try await appState.sessionManager.open(connection: connection)
                    let tab = SessionTab(
                        connectionId: connection.id,
                        sessionId: sessionId,
                        title: connection.name
                    )
                    appState.workspace.addTab(tab)
                    try appState.connectionService.markConnected(connection)
                } catch {
                    appState.toastMessage = ToastMessage(
                        title: "Connection Failed",
                        message: error.localizedDescription,
                        style: .error
                    )
                }
            }
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

    // Determine the status of this connection based on active sessions
    private var sessionState: SessionState {
        let activeSession = appState.sessionManager.sessions.values
            .first(where: { $0.connectionId == connection.id })
        return activeSession?.state ?? .idle
    }

    var body: some View {
        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(sessionState.statusColor.color)
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
            Button("Connect") {
                Task {
                    await openConnection(connection)
                }
            }
            Divider()

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
            Button("Edit...") {
                appState.editingConnection = connection
                appState.isShowingConnectionSheet = true
            }
            Button(connection.isFavorite ? "Unfavorite" : "Favorite") {
                try? appState.connectionService.toggleFavorite(connection)
            }
            Divider()
            Button("Delete", role: .destructive) {
                try? appState.connectionService.delete(connection)
            }
        }
    }

    private func openConnection(_ connection: Connection) async {
        do {
            let sessionId = try await appState.sessionManager.open(connection: connection)
            let tab = SessionTab(
                connectionId: connection.id,
                sessionId: sessionId,
                title: connection.name
            )
            appState.workspace.addTab(tab)
            try appState.connectionService.markConnected(connection)
        } catch {
            appState.toastMessage = ToastMessage(
                title: "Connection Failed",
                message: error.localizedDescription,
                style: .error
            )
        }
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

    var body: some View {
        // Access dataVersion to register observation dependency — when loadAll()
        // runs, SwiftUI will re-evaluate this body without destroying the view
        let _ = appState.connectionService.dataVersion
        DisclosureGroup {
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
            .contextMenu {
                Button {
                    appState.folderActionTarget = folder
                    appState.folderAlertText = folder.name
                    appState.isShowingRenameFolderAlert = true
                } label: {
                    Label("Rename Folder", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    try? appState.connectionService.deleteFolder(folder)
                } label: {
                    Label("Delete Folder", systemImage: "trash")
                }
                Divider()
                Button {
                    appState.folderActionTarget = folder
                    appState.folderAlertText = ""
                    appState.isShowingNewFolderAlert = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
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
