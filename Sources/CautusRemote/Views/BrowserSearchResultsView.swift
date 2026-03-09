import SwiftUI

struct BrowserSearchResultsView: View {
    let query: String
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var windowModel: MainWindowViewModel

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var connectionResults: [Connection] {
        (try? appState.connectionService.search(query: trimmedQuery)) ?? []
    }

    private var folderResults: [Folder] {
        let lowered = trimmedQuery.lowercased()
        return appState.connectionService
            .allFoldersFlattened()
            .map(\.folder)
            .filter { folder in
                folder.name.lowercased().contains(lowered)
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Search results for \"\(trimmedQuery)\"")
                .font(.title2)
                .fontWeight(.semibold)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !connectionResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Connections")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            ForEach(connectionResults) { connection in
                                BrowserSearchConnectionRow(connection: connection)
                            }
                        }
                    }

                    if !folderResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Folders")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            ForEach(folderResults) { folder in
                                BrowserSearchFolderRow(folder: folder)
                            }
                        }
                    }

                    if connectionResults.isEmpty && folderResults.isEmpty {
                        Text("No results")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct BrowserSearchConnectionRow: View {
    let connection: Connection

    @Environment(AppState.self) private var appState
    @EnvironmentObject private var windowModel: MainWindowViewModel

    private var locationPath: String {
        var parts: [String] = []
        var folder = connection.folder
        while let f = folder {
            parts.append(f.name)
            folder = f.parentFolder
        }
        let chain = parts.reversed().joined(separator: " › ")
        return chain.isEmpty ? "Unfiled" : chain
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "desktopcomputer")
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.name)
                        .fontWeight(.medium)
                    Text(connection.displayAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(locationPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                windowModel.browserSelection = .connection(connection.id)
            }
            .onTapGesture(count: 2) {
                openSession()
            }
        }
    }

    private func openSession() {
        Task { @MainActor in
            // Focus existing tab if any
            if let existing = appState.workspace.tabs.first(where: { $0.connectionId == connection.id }) {
                appState.workspace.activeTabId = existing.id
                return
            }
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
}

private struct BrowserSearchFolderRow: View {
    let folder: Folder

    @Environment(AppState.self) private var appState
    @EnvironmentObject private var windowModel: MainWindowViewModel

    private var locationPath: String {
        var parts: [String] = []
        var current: Folder? = folder
        while let f = current {
            parts.append(f.name)
            current = f.parentFolder
        }
        return parts.reversed().joined(separator: " › ")
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .fontWeight(.medium)
                if !locationPath.isEmpty {
                    Text(locationPath)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            windowModel.browserSelection = .folder(folder.id)
        }
    }
}

