import SwiftUI

struct MainContentRootView: View {
    @EnvironmentObject private var windowModel: MainWindowViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()
            if appState.workspace.activeTabId == nil {
                switch windowModel.browserSelection {
                case .welcome:
                    EmptyStateView()
                case .folder(let id):
                    if let folder = appState.connectionService.folder(id) {
                        FolderSummaryView(folder: folder)
                    } else {
                        EmptyStateView()
                    }
                case .connection(let id):
                    if let connection = appState.connectionService.connection(id) {
                        ConnectionSummaryView(connection: connection)
                    } else {
                        EmptyStateView()
                    }
                case .search(let query):
                    BrowserSearchResultsView(query: query)
                }
            } else {
                WorkspaceView()
            }
        }
    }
}
