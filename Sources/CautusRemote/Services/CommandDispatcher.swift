import Foundation

/// Routes command palette actions to the appropriate services.
@MainActor
final class CommandDispatcher {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Search

    /// Generate palette results for a query string.
    func search(query: String) -> [PaletteResult] {
        var results: [PaletteResult] = []

        // Always show "New Connection" as a command
        results.append(PaletteResult(
            title: "New Connection",
            icon: "plus.circle",
            action: .newConnection,
            score: query.isEmpty ? 0.5 : 0
        ))

        // Search connections
        let connections = appState.connectionService.allConnections
        for connection in connections {
            let matchScore = FuzzySearch.score(
                query: query,
                candidate: connection.name,
                isFavorite: connection.isFavorite,
                isRecent: connection.lastConnectedAt != nil
            )
            if query.isEmpty || matchScore > 0 {
                results.append(PaletteResult(
                    title: "Open \(connection.name)",
                    subtitle: connection.displayAddress,
                    icon: "server.rack",
                    action: .openConnection(connection.id),
                    score: matchScore
                ))
            }
        }

        // Open tabs as "Switch to..." commands
        for tab in appState.workspace.tabs {
            let matchScore = FuzzySearch.score(query: query, candidate: tab.title)
            if query.isEmpty || matchScore > 0 {
                results.append(PaletteResult(
                    title: "Switch to \(tab.title)",
                    icon: "arrow.right.square",
                    action: .switchTab(tab.id),
                    score: matchScore
                ))
            }
        }

        // Add split pane commands when tabs are open
        if !appState.workspace.isEmpty {
            if query.isEmpty || FuzzySearch.score(query: query, candidate: "split horizontal") > 0 {
                results.append(PaletteResult(
                    title: "Split Pane Horizontal",
                    icon: "rectangle.split.2x1",
                    action: .splitPane(.horizontal),
                    score: FuzzySearch.score(query: query, candidate: "split horizontal")
                ))
            }
            if query.isEmpty || FuzzySearch.score(query: query, candidate: "split vertical") > 0 {
                results.append(PaletteResult(
                    title: "Split Pane Vertical",
                    icon: "rectangle.split.1x2",
                    action: .splitPane(.vertical),
                    score: FuzzySearch.score(query: query, candidate: "split vertical")
                ))
            }
        }

        // Sort by score descending
        results.sort { $0.score > $1.score }
        return results
    }

    // MARK: - Dispatch

    /// Execute a palette action.
    func dispatch(_ action: PaletteAction) async {
        appState.palette.hide()

        switch action {
        case .openConnection(let id):
            await openConnection(id: id)
        case .switchTab(let id):
            appState.workspace.activeTabId = id
        case .reconnect(let sessionId):
            try? await appState.sessionManager.reconnect(sessionId: sessionId)
        case .duplicateSession:
            // TODO: Phase 3 — duplicate the session's connection
            break
        case .splitPane:
            // TODO: Phase 3 — implement split
            break
        case .editConnection(let id):
            let connection = try? appState.connectionService.search(query: "")
                .first(where: { $0.id == id })
            if let connection {
                appState.editingConnection = connection
                appState.isShowingConnectionSheet = true
            }
        case .newConnection:
            appState.editingConnection = nil
            appState.isShowingConnectionSheet = true
        case .closeTab(let id):
            appState.workspace.closeTab(id: id)
        }
    }

    // MARK: - Private

    private func openConnection(id: UUID) async {
        do {
            guard let connection = try appState.connectionService.search(query: "")
                .first(where: { $0.id == id }) else { return }

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
