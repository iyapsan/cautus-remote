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

    // MARK: - RDP Patch (stored as JSON blob; decode only at connect time or in settings sheets)

    /// Raw JSON blob for this folder's RDP patch.
    /// Renamed from `rdpDefaultsData` per the formal spec.
    /// SwiftData stores this as a binary attribute — JSON format is forward-compatible with the rename.
    var rdpPatchData: Data?

    /// Decoded RDP patch for this folder.
    /// `nil` means this folder contributes nothing to the resolution chain (full inherit).
    /// Only decode when actually needed — not during sidebar list rendering.
    var rdpPatch: RDPPatch? {
        get { rdpPatchData.flatMap { try? JSONDecoder().decode(RDPPatch.self, from: $0) } }
        set { rdpPatchData = newValue.flatMap { try? JSONEncoder().encode($0) } }
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
