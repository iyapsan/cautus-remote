# Cautus Remote — Technical Architecture Document

**Version:** 1.0
**Date:** 2026-02-21

---

## 1. Architectural Goals

- Fully native macOS application
- Modular and extensible
- SSH-first architecture
- Clean separation of UI and networking layers
- Prepared for future RDP/VNC expansion
- Persistence abstracted behind repository protocol

---

## 2. High-Level Architecture

```
Presentation Layer (SwiftUI + AppKit Hybrid)
    ↕ Combine / @Observable
Application Layer (State + Session Orchestration)
    ↕ Repository Protocol
Domain Layer (Connection Models)
    ↕
Infrastructure Layer (SSH Engine + SwiftData + Keychain)
```

---

## 3. Confirmed Technology Stack

| Layer | Technology |
|-------|-----------|
| Presentation | SwiftUI + AppKit bridging (`NSViewRepresentable`) |
| State Management | `@Observable` / `ObservableObject` + Combine |
| SSH Engine | SwiftNIO SSH ~> 0.12.0 |
| Terminal | SwiftTerm (AppKit `TerminalView`) |
| Persistence | SwiftData via `ConnectionRepository` protocol |
| Secure Storage | Raw `Security.framework` (Keychain Services) |
| Build | Xcode 26.2 + Swift Package Manager |
| Testing | XCTest + Docker SSH server |

---

## 4. Module Breakdown

### 4.1 Presentation Layer

Components:
- MainWindowController (AppKit — advanced window control)
- SidebarView (SwiftUI)
- TabManagerView (SwiftUI)
- WorkspaceView (SwiftUI)
- TerminalContainerView (SwiftUI wrapping AppKit `TerminalView`)
- CommandPaletteView (SwiftUI)
- ConnectionSheetView (SwiftUI)
- EmptyStateView (SwiftUI)
- SplitPaneView (SwiftUI wrapping `NSSplitView`)

Framework approach:
- SwiftUI for layout and declarative UI
- AppKit bridging for advanced window control, terminal embedding, and native split views
- Combine for state updates

---

### 4.2 Application Layer

Responsible for:
- Session lifecycle
- Split view orchestration
- Command palette dispatching
- Status updates

Core Managers:
- **SessionManager** — Active session lifecycle, state publishing via Combine
- **ConnectionManager** — CRUD via `ConnectionRepository` protocol
- **WindowLayoutManager** — Split pane tree, tab management
- **CommandDispatcher** — Routes palette commands to managers

---

### 4.3 Domain Layer

Entities:
- `Connection` — SSH connection configuration
- `Folder` — Hierarchical organization
- `Tag` — Flexible labeling
- `SessionState` — Enum: connecting, connected, reconnecting, failed, disconnected

All entities immutable where possible.

---

### 4.4 Infrastructure Layer

#### SSH Engine (SwiftNIO SSH)

- Async connection handling via Swift concurrency
- Password and public key authentication
- Jump host / proxy command support
- PTY allocation for interactive shell
- Keepalive management
- Reconnect logic with exponential backoff

#### Persistence (SwiftData, abstracted)

```swift
protocol ConnectionRepository {
    func fetchAll() async throws -> [Connection]
    func fetch(id: UUID) async throws -> Connection?
    func save(_ connection: Connection) async throws
    func delete(_ connection: Connection) async throws
    func fetchFolders() async throws -> [Folder]
    func fetchTags() async throws -> [Tag]
    func fetchRecents(limit: Int) async throws -> [Connection]
}
```

v1 implementation: `SwiftDataRepository`
- Automatic save on mutation
- Migration support via SwiftData `VersionedSchema`
- Future-proof: swap to GRDB, SQLite, or Core Data without touching business logic

#### Secure Storage (Raw Security.framework)

- macOS Keychain Services API
- Thin `KeychainService` wrapper: store/retrieve/delete passwords and key references
- No third-party dependencies

---

## 5. State Management

- Single source of truth (`AppState`)
- `@Observable` root container (or `ObservableObject` where needed)
- Session states published via Combine

Session States:
- Connecting
- Connected
- Reconnecting
- Failed(Error)
- Disconnected

---

## 6. Split View System

- Tree-based pane layout model
- Recursive split container nodes
- Max depth limited to 2 (2×2 grid)
- Backed by `NSSplitView` for native resize behavior

```
SplitNode
 ├── .terminal(sessionId)
 └── .split(orientation, [SplitNode])
```

---

## 7. Data Flow

```
User Action → CommandDispatcher → SessionManager → SSH Engine → State Update → UI Refresh
                                       ↕
                              ConnectionRepository (SwiftData)
                                       ↕
                              KeychainService (Security.framework)
```

---

## 8. Security Model

- All credentials in macOS Keychain via raw `Security.framework`
- SSH keys referenced by file path (not stored)
- No external network calls except SSH target
- No telemetry

---

## 9. Future Extensibility

Prepared interfaces:

| Abstraction | Purpose | Future Use |
|-------------|---------|------------|
| `RemoteProtocol` | Protocol-agnostic session interface | RDP, VNC, Telnet engines |
| `ProtocolRegistry` | Dynamic protocol discovery | Plugin-like protocol loading |
| `ConnectionRepository` | Persistence abstraction | Migration to GRDB, SQLite, Core Data |
| Theming layer | Appearance abstraction (future) | Custom themes beyond system appearance |

Candidate libraries for future protocols:
- **VNC**: RoyalVNCKit (pure Swift, `NSView` subclass)
- **RDP**: FreeRDP (C interop, bridging header)
- **Telnet**: SwiftNIO raw TCP + custom handler

---

## 10. Build & Deployment

- Xcode 26.2 + Swift 6.2
- Swift Package Manager for dependencies
- Target macOS 14+
- Apple Silicon optimized (arm64)
- App Sandbox enabled
- Notarized for distribution

### Dependencies (v1)

| Package | Version | Purpose |
|---------|---------|---------|
| `swift-nio-ssh` | ~> 0.12.0 | SSH protocol engine |
| `SwiftTerm` | latest | Terminal emulator |

No additional third-party dependencies.

---

## 11. Testing Infrastructure

- **Unit tests**: XCTest for domain models, state management, command dispatch
- **SSH integration tests**: Docker container (`alpine` + `openssh-server`)
  - Password auth (`testuser` / `testpass`)
  - Key-based auth (generated test keypair)
  - Jump host simulation (second container)
- **UI tests**: XCTest UI testing for critical flows
