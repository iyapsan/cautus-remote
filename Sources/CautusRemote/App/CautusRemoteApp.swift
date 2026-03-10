import SwiftUI
import SwiftData
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        super.init()
    }
    
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activate as foreground app (required for SPM-built executables)
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Restore default behaviour: open a new implicit main window by re-sending a New Window event
            NSApp.sendAction(Selector(("newDocument:")), to: nil, from: self)
            return true
        }
        return false
    }
}

/// Cautus Remote — macOS native SSH connection manager.
struct CautusRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState: AppState
    @State private var sessionCoordinator: SessionCoordinator
    let modelContainer: ModelContainer

    init() {
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

        let state = AppState(
            sessionManager: sessionManager,
            connectionService: connectionService,
            keychainService: keychainService
        )
        
        _appState = State(initialValue: state)
        _sessionCoordinator = State(initialValue: SessionCoordinator(appState: state, modelContainer: container))

        // Load initial data
        try? connectionService.loadAll()
    }

    var body: some Scene {
        WindowGroup(id: "main", for: WindowTabKind.self) { $tabKind in
            MainWindowView(tabKind: tabKind)
                .environment(appState)
                .environment(sessionCoordinator)
        } defaultValue: {
            .browse
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .modelContainer(modelContainer)
        .commands {
            CautusCommands(appState: appState, coordinator: sessionCoordinator)
        }
    }
}

struct CautusCommands: Commands {
    let appState: AppState
    let coordinator: SessionCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                coordinator.openBrowse(openWindow: openWindow)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Connection") {
                appState.isShowingConnectionSheet = true
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandMenu("Session") {
            Button("Command Palette") {
                appState.palette.isVisible.toggle()
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("New Session Tab") {
                appState.isShowingConnectionSheet = true
            }
            .keyboardShortcut("t", modifiers: .command)
        }
        CommandMenu("Connections") {
            Button("Edit Global Defaults…") {
                appState.isShowingGlobalDefaultsSheet = true
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
        }
    }
}

@main
struct AppLauncher {
    static func main() throws {
        // Purge the old explicitly forced generic tabs setting from earlier builds.
        UserDefaults.standard.removeObject(forKey: "AppleWindowTabbingMode")
        CautusRemoteApp.main()
    }
}
