import Foundation

/// State for the workspace content area — tabs and split panes.
@Observable
final class WorkspaceState {
    /// Ordered list of open session tabs
    var tabs: [SessionTab] = []

    /// Currently active (focused) tab ID
    var activeTabId: UUID?

    /// Split pane tree — nil means single pane view
    var splitRoot: SplitNode?

    /// ID of the focused pane within a split layout
    var focusedPaneId: UUID?

    // MARK: - Computed

    var activeTab: SessionTab? {
        tabs.first { $0.id == activeTabId }
    }

    /// The split root for the active tab (nil = single pane)
    var activeSplitRoot: SplitNode? {
        splitRoot
    }

    var isEmpty: Bool { tabs.isEmpty }

    // MARK: - Tab Operations

    func addTab(_ tab: SessionTab) {
        tabs.append(tab)
        activeTabId = tab.id
    }

    func closeTab(id: UUID) {
        tabs.removeAll { $0.id == id }
        if activeTabId == id {
            activeTabId = tabs.last?.id
        }
    }

    func closeActiveTab() {
        guard let id = activeTabId else { return }
        closeTab(id: id)
    }

    // MARK: - Focus Navigation

    func focusNextPane() {
        guard let root = splitRoot else { return }
        let paneIds = root.allTerminalIds
        guard let currentIndex = paneIds.firstIndex(where: { $0 == focusedPaneId }) else {
            focusedPaneId = paneIds.first
            return
        }
        let nextIndex = (currentIndex + 1) % paneIds.count
        focusedPaneId = paneIds[nextIndex]
    }

    func focusPreviousPane() {
        guard let root = splitRoot else { return }
        let paneIds = root.allTerminalIds
        guard let currentIndex = paneIds.firstIndex(where: { $0 == focusedPaneId }) else {
            focusedPaneId = paneIds.last
            return
        }
        let prevIndex = (currentIndex - 1 + paneIds.count) % paneIds.count
        focusedPaneId = paneIds[prevIndex]
    }
}

// MARK: - Session Tab

/// Represents one open session tab.
struct SessionTab: Identifiable, Sendable {
    let id: UUID
    let connectionId: UUID
    let sessionId: UUID
    var title: String
    var state: SessionState

    init(connectionId: UUID, sessionId: UUID, title: String) {
        self.id = UUID()
        self.connectionId = connectionId
        self.sessionId = sessionId
        self.title = title
        self.state = .connecting
    }
}

// MARK: - Split Pane Model

/// Recursive tree representing split pane layouts.
///
/// Max depth is 2, yielding a maximum of 4 terminal panes (2×2 grid).
indirect enum SplitNode: Identifiable, Sendable {
    case terminal(id: UUID, sessionId: UUID)
    case split(id: UUID, orientation: SplitOrientation, children: [SplitNode])

    var id: UUID {
        switch self {
        case .terminal(let id, _): return id
        case .split(let id, _, _): return id
        }
    }

    /// Count of terminal leaf nodes
    var paneCount: Int {
        switch self {
        case .terminal: return 1
        case .split(_, _, let children):
            return children.reduce(0) { $0 + $1.paneCount }
        }
    }

    /// Whether another split is allowed (max 4 panes)
    var canSplit: Bool { paneCount < 4 }

    /// All terminal IDs in tree order (for focus navigation)
    var allTerminalIds: [UUID] {
        switch self {
        case .terminal(let id, _):
            return [id]
        case .split(_, _, let children):
            return children.flatMap { $0.allTerminalIds }
        }
    }
}

enum SplitOrientation: Sendable {
    /// Side by side (left | right)
    case horizontal
    /// Stacked (top / bottom)
    case vertical
}
