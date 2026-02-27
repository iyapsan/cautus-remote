import SwiftUI

/// State for the sidebar navigation panel.
@Observable
final class SidebarState {
    /// Current search query
    var searchQuery: String = ""

    /// Currently selected connection IDs (supports multi-select with Cmd/Shift+Click)
    var selectedConnectionIds: Set<UUID> = []

    /// NavigationSplitView column visibility
    var columnVisibility: NavigationSplitViewVisibility = .automatic

    /// Section expansion states
    var isFavoritesExpanded = true
    var isAllConnectionsExpanded = true
    var isTagsExpanded = true
    var isRecentsExpanded = true

    /// Which folder IDs are expanded in the "All Connections" tree
    var expandedFolderIds: Set<UUID> = []
}
