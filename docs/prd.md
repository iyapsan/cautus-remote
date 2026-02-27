# Cautus Remote — Product Requirements Document

**App Name:** Cautus Remote
**Version:** 1.0
**Date:** 2026-02-21
**Platform:** macOS 14+
**Architecture Constraint:** Fully Native (Swift + SwiftUI/AppKit Hybrid)

---

## 1. Product Vision

Build a premium, clutter-free, macOS-native remote connection manager focused on SSH-first workflows for developers and IT administrators.

### Positioning

A calm, professional remote workspace designed for serious infrastructure work without visual chaos.

---

## 2. Core Principles

1. Single-window architecture
2. Minimal visible controls
3. Keyboard-first navigation
4. Progressive disclosure
5. Subtle status indicators
6. Follow system light/dark mode
7. High performance and low memory usage

---

## 3. Target Users

### Developer

- Uses SSH daily
- Uses jump hosts
- Prefers keyboard navigation
- Works with split sessions

### IT Administrator

- Manages structured environments
- Needs credential storage
- Requires connection health visibility

---

## 4. Scope (v1)

### Supported Protocol

- SSH

### Explicitly Not Included (v1)

- RDP
- VNC
- Telnet
- Themes
- Plugins
- Multi-window sessions

### Future Protocol Extensibility

The architecture includes a `RemoteProtocol` abstraction prepared for future protocol support:

| Protocol | Library Candidate | Integration |
|----------|------------------|-------------|
| VNC | RoyalVNCKit (pure Swift) | Direct SPM, `NSViewRepresentable` |
| RDP | FreeRDP (C interop) | C bridging header |
| Telnet | SwiftNIO raw TCP | Thin protocol handler |

---

## 5. Technology Stack (Confirmed)

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Language | **Swift 6.2** | Native, modern, type-safe |
| UI Framework | **SwiftUI + AppKit Hybrid** | SwiftUI for layout, AppKit for advanced window control |
| SSH Engine | **SwiftNIO SSH** ~> 0.12.0 | Pure Swift, async/await, actively maintained |
| Terminal Emulator | **SwiftTerm** | Mature VT100/Xterm with AppKit `TerminalView` |
| Persistence | **SwiftData** (macOS 14+) | Apple-native, abstracted behind `Repository` protocol |
| Secure Storage | **Raw `Security.framework`** | Zero third-party dependencies, thin custom wrapper |
| Build System | **Xcode 26.2** + SPM | Full `.app` bundle, sandboxing, code signing |
| Testing Infrastructure | **Docker** | Local SSH server for integration tests |

---

## 6. UI Requirements

### 6.1 Window Model

- Single main window
- Sessions as tabs
- Drag-to-split support (max 4 panes)

### 6.2 Toolbar

Left:
- Sidebar toggle

Right:
- Command palette (⌘K)
- New connection (+)

No additional visible buttons.

---

### 6.3 Sidebar

Sections:
- Favorites
- All Connections (hierarchical)
- Tags
- Recents

Includes search at top.

#### Status Indicators

Small dot (6–8px):
- Green: Connected
- Yellow: Reconnecting
- Red: Failed
- Gray/None: Inactive

---

### 6.4 Workspace

#### Empty State

Centered:
- "No Active Sessions"
- New Connection button
- Quick Connect field

#### Active SSH Session

- Full-bleed terminal
- Minimal session header
- No persistent action toolbar

---

### 6.5 Command Palette (⌘K)

Must support:
- Search connections
- Open connection
- Switch tabs
- Reconnect
- Split pane
- Edit connection

---

## 7. Connection Model

### Connection Fields

- id (UUID)
- name
- host
- port
- username
- auth_method
- ssh_key_path
- jump_host_id
- tags
- folder_id
- is_favorite
- created_at
- updated_at

---

## 8. Security

- Credentials stored in macOS Keychain via raw `Security.framework`
- No plaintext storage
- No telemetry (v1)
- No third-party dependencies for security-critical operations

---

## 9. Performance Requirements

- Launch < 1.5 seconds
- Smooth 120–180ms animations
- Memory < 200MB typical usage

---

## 10. Persistence Architecture

The persistence layer is abstracted behind a `ConnectionRepository` protocol:

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

v1 uses `SwiftDataRepository` as the concrete implementation. This abstraction allows migration to GRDB, SQLite, or Core Data in the future without touching business logic or UI.

---

## 11. Acceptance Criteria

v1 complete when:
- SSH connections can be created
- Folder organization works
- Sessions open as tabs
- Split panes work (max 4)
- Command palette operational
- Status indicators functional
- Credentials securely stored in macOS Keychain
- Repository abstraction in place for persistence
- Docker-based integration tests pass
