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
            print("Failed to load ModelContainer: \(error). Wiping store and starting fresh...")
            do {
                let config = ModelConfiguration()
                let url = config.url
                let shmUrl = url.deletingPathExtension().appendingPathExtension("store-shm")
                let walUrl = url.deletingPathExtension().appendingPathExtension("store-wal")
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(at: shmUrl)
                try? FileManager.default.removeItem(at: walUrl)
                container = try ModelContainer(for: Connection.self, Folder.self, Tag.self)
            } catch {
                let errStr = "Failed to create ModelContainer after wipe: \(error)"
                try? errStr.write(toFile: "/tmp/cautus_crash.log", atomically: true, encoding: .utf8)
                fatalError(errStr)
            }
        }
        self.modelContainer = container

        // Initialize services with real SwiftData repository
        let keychainService = KeychainService()
        let sessionManager = SessionManager(keychainService: keychainService)

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
            CommandMenu("Connections") {
                Button("Edit Global Defaults…") {
                    appState.isShowingGlobalDefaultsSheet = true
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }
    }
}
