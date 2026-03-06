import SwiftUI
import SwiftData

/// Root application state — single source of truth.
///
/// Owns child state objects and service references.
/// Injected into the SwiftUI environment at the app level.
@MainActor
@Observable
final class AppState {
    // MARK: - Child State

    var sidebar = SidebarState()
    var workspace = WorkspaceState()
    var palette = PaletteState()

    // MARK: - Services

    let sessionManager: SessionManager
    let connectionService: ConnectionService
    let keychainService: KeychainService

    // MARK: - Global UI State

    var isShowingConnectionSheet = false
    var editingConnection: Connection?
    var toastMessage: ToastMessage?

    // MARK: - Global RDP Defaults

    /// App-wide baseline configuration.
    /// Persisted as JSON in UserDefaults — avoids SwiftData schema changes.
    /// Loaded once at startup; all resolvers get this passed explicitly.
    var globalRDPDefaults: RDPResolvedConfig {
        get { Self.loadGlobalDefaults() }
        set { Self.saveGlobalDefaults(newValue) }
    }

    var isShowingGlobalDefaultsSheet = false

    private static let globalDefaultsKey = "com.cautus.globalRDPDefaults"

    private static func loadGlobalDefaults() -> RDPResolvedConfig {
        guard let data = UserDefaults.standard.data(forKey: globalDefaultsKey),
              let config = try? JSONDecoder().decode(RDPResolvedConfig.self, from: data)
        else { return .global }
        return config.validated()
    }

    private static func saveGlobalDefaults(_ config: RDPResolvedConfig) {
        let data = try? JSONEncoder().encode(config.validated())
        UserDefaults.standard.set(data, forKey: globalDefaultsKey)
    }

    // Folder actions (shared so FolderRow context menus and SidebarView alerts don't conflict)
    var folderActionTarget: Folder?
    var isShowingNewFolderAlert = false
    var isShowingRenameFolderAlert = false
    var folderAlertText = ""

    // MARK: - Init

    init(
        sessionManager: SessionManager,
        connectionService: ConnectionService,
        keychainService: KeychainService = KeychainService()
    ) {
        self.sessionManager = sessionManager
        self.connectionService = connectionService
        self.keychainService = keychainService
    }

    /// Returns the ID of a folder currently selected in the sidebar, if any.
    /// Used to pre-fill the folder field when creating a new connection.
    var selectedFolderIdForNewConnection: UUID? {
        let folderIds = Set(connectionService.allFoldersFlattened().map(\.folder.id))
        return sidebar.selectedConnectionIds.first(where: { folderIds.contains($0) })
    }
}

// MARK: - Toast

/// Non-blocking notification message.
struct ToastMessage: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String
    let style: Style

    enum Style: Sendable {
        case info
        case success
        case warning
        case error
    }
}
