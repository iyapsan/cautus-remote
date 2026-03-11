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
}

/// Cautus Remote — macOS native SSH connection manager.
struct CautusRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var appState: AppState
    @State private var sessionRegistry: SessionRegistry
    @State private var browseCoordinator: BrowseCoordinator
    @State private var detachedWindowManager: DetachedSessionWindowManager
    
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
        
        // 1. Domain Object: Canonical Session Memory
        let registry = SessionRegistry(keychainService: keychainService)
        
        // 2. Main Window Surface Coordinator
        let browseCoord = BrowseCoordinator(sessionRegistry: registry)
        
        // 3. Detached Native Window Coordinator
        let detachedManager = DetachedSessionWindowManager(sessionRegistry: registry)
        
        // Break dependency cycle safely explicitly setting factory here
        detachedManager.createWindowContent = { sessionID in
            AnyView(
                WorkspaceView(sessionId: sessionID, isFocused: true)
                    .environment(state)
                    .environment(registry)
            )
        }
        
        _appState = State(initialValue: state)
        _sessionRegistry = State(initialValue: registry)
        _browseCoordinator = State(initialValue: browseCoord)
        _detachedWindowManager = State(initialValue: detachedManager)

        // Load initial data
        try? connectionService.loadAll()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindowView()
                .environment(appState)
                .environment(sessionRegistry)
                .environment(browseCoordinator)
                .environment(detachedWindowManager)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .modelContainer(modelContainer)
        .commands {
            CautusCommands(
                appState: appState,
                browseCoordinator: browseCoordinator,
                registry: sessionRegistry
            )
        }
    }
}

struct CautusCommands: Commands {
    let appState: AppState
    let browseCoordinator: BrowseCoordinator
    let registry: SessionRegistry

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Connection") {
                appState.isShowingConnectionSheet = true
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Button("Close Current Tab/Window") {
                browseCoordinator.closeCurrentSurface()
            }
            .keyboardShortcut("w", modifiers: .command)
        }
        
        CommandMenu("Session") {
            Button("Command Palette") {
                appState.palette.isVisible.toggle()
            }
            .keyboardShortcut("k", modifiers: .command)
            
            Divider()

            Button("Focus Browse") {
                browseCoordinator.focusBrowse()
            }
            .keyboardShortcut("1", modifiers: .command)
            
            Button("Next Tab") {
                browseCoordinator.selectNextSurface()
            }
            .keyboardShortcut(.tab, modifiers: .control)
            
            Button("Previous Tab") {
                browseCoordinator.selectPreviousSurface()
            }
            .keyboardShortcut(.tab, modifiers: [.control, .shift])
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
        NSWindow.allowsAutomaticWindowTabbing = false
        CautusRemoteApp.main()
    }
}
