import SwiftUI
import SwiftData
import AppKit

/// Cautus Remote — macOS native SSH connection manager.
@main
struct CautusRemoteApp: App {
    @State private var appState: AppState
    let modelContainer: ModelContainer

    init() {
        // Activate as foreground app (required for SPM-built executables)
        NSApplication.shared.setActivationPolicy(.regular)

        // Create SwiftData container programmatically so we can inject it
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Connection.self, Folder.self, Tag.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        self.modelContainer = container

        // Initialize services with real SwiftData repository
        let keychainService = KeychainService()
        let sshEngine = SSHEngine()
        let sessionManager = SessionManager(engine: sshEngine, keychainService: keychainService)

        let repository = SwiftDataRepository(modelContext: container.mainContext)
        let connectionService = ConnectionService(
            repository: repository,
            keychainService: keychainService
        )

        _appState = State(initialValue: AppState(
            sessionManager: sessionManager,
            connectionService: connectionService,
            keychainService: keychainService
        ))

        // Load initial data
        try? connectionService.loadAll()
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(appState)
        }
        .modelContainer(modelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Connection") {
                    appState.isShowingConnectionSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Session") {
                Button("Command Palette") {
                    appState.palette.isVisible.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                Button("Close Tab") {
                    appState.workspace.closeActiveTab()
                }
                .keyboardShortcut("w", modifiers: .command)

                Divider()

                Button("Previous Pane") {
                    appState.workspace.focusPreviousPane()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])

                Button("Next Pane") {
                    appState.workspace.focusNextPane()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            }
        }
    }
}
