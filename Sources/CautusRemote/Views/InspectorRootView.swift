import SwiftUI

struct InspectorRootView: View {
    @EnvironmentObject private var windowModel: MainWindowViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch windowModel.inspectorSelection {
            case .none:
                EmptyInspectorView()

            case .globalDefaults:
                GlobalDefaultsInspectorView()

            case .folder(let id):
                if let folder = appState.connectionService.allFoldersFlattened().map(\.folder).first(where: { $0.id == id }) {
                    FolderInspectorView(folder: folder)
                } else {
                    EmptyInspectorView(message: "Folder no longer exists.")
                }

            case .connection(let id):
                if let connection = appState.connectionService.allConnections.first(where: { $0.id == id }) {
                    ConnectionInspectorView(connection: connection)
                } else {
                    EmptyInspectorView(message: "Connection no longer exists.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
