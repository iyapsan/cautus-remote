import Foundation

/// State for the command palette overlay (⌘K).
@Observable
final class PaletteState {
    /// Whether the palette is currently visible
    var isVisible = false

    /// Current search query
    var query: String = ""

    /// Computed search results
    var results: [PaletteResult] = []

    /// Currently highlighted result index
    var selectedIndex: Int = 0

    // MARK: - Operations

    func show() {
        query = ""
        results = []
        selectedIndex = 0
        isVisible = true
    }

    func hide() {
        isVisible = false
        query = ""
    }

    func selectNext() {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % results.count
    }

    func selectPrevious() {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + results.count) % results.count
    }

    var selectedResult: PaletteResult? {
        guard results.indices.contains(selectedIndex) else { return nil }
        return results[selectedIndex]
    }
}

// MARK: - Palette Result

/// A single result in the command palette.
struct PaletteResult: Identifiable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String?
    let icon: String           // SF Symbol name
    let action: PaletteAction
    let score: Double          // for ranking (higher = better match)

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        action: PaletteAction,
        score: Double = 0
    ) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
        self.score = score
    }
}

// MARK: - Palette Action

/// Actions that can be triggered from the command palette.
enum PaletteAction: Sendable {
    case openConnection(UUID)
    case switchTab(UUID)
    case reconnect(UUID)
    case duplicateSession(UUID)
    case splitPane(SplitOrientation)
    case editConnection(UUID)
    case newConnection
    case closeTab(UUID)
}
