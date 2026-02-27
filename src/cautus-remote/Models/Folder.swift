import Foundation
import SwiftData

/// Hierarchical folder for organizing connections.
@Model
final class Folder {
    @Attribute(.unique)
    var id: UUID

    var name: String

    /// Parent folder — nil means root level
    var parentFolder: Folder?

    @Relationship(inverse: \Connection.folder)
    var connections: [Connection]

    @Relationship(inverse: \Folder.parentFolder)
    var subfolders: [Folder]

    /// Display order within parent
    var sortOrder: Int

    var createdAt: Date

    // MARK: - Computed

    /// Whether this is a root-level folder
    var isRoot: Bool { parentFolder == nil }

    /// Total connection count including subfolders (recursive)
    var totalConnectionCount: Int {
        connections.count + subfolders.reduce(0) { $0 + $1.totalConnectionCount }
    }

    // MARK: - Init

    init(name: String, parent: Folder? = nil) {
        self.id = UUID()
        self.name = name
        self.parentFolder = parent
        self.connections = []
        self.subfolders = []
        self.sortOrder = 0
        self.createdAt = .now
    }
}
