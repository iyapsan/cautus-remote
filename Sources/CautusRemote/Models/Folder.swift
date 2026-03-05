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

    // MARK: - RDP Profile Defaults (stored as JSON blob to avoid SwiftData migrations)

    /// Raw JSON blob. Use `rdpDefaults` accessor — decode only at connect time or in settings sheets.
    var rdpDefaultsData: Data?

    /// Decoded RDP defaults for this folder.
    /// `nil` means "inherit from parent". Only decode when actually needed (not in list cells).
    var rdpDefaults: RDPProfileDefaults? {
        get { rdpDefaultsData.flatMap { try? JSONDecoder().decode(RDPProfileDefaults.self, from: $0) } }
        set { rdpDefaultsData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

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
