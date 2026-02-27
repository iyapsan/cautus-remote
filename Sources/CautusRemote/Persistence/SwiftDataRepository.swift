import Foundation
import SwiftData

/// SwiftData-backed implementation of `ConnectionRepository`.
///
/// This is the v1 persistence layer. The `ConnectionRepository` protocol
/// allows swapping to GRDB, SQLite, or Core Data in the future.
///
/// Runs on `@MainActor` because SwiftData model objects
/// are not `Sendable` and must stay in one isolation domain.
@MainActor
final class SwiftDataRepository: ConnectionRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Connections

    func fetchAll() throws -> [Connection] {
        let descriptor = FetchDescriptor<Connection>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Connection? {
        let descriptor = FetchDescriptor<Connection>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func save(_ connection: Connection) throws {
        connection.updatedAt = .now
        modelContext.insert(connection)
        try modelContext.save()
    }

    func delete(_ connection: Connection) throws {
        modelContext.delete(connection)
        try modelContext.save()
    }

    func search(query: String) throws -> [Connection] {
        let lowered = query.lowercased()
        let descriptor = FetchDescriptor<Connection>(
            predicate: #Predicate {
                $0.name.localizedStandardContains(lowered)
                || $0.host.localizedStandardContains(lowered)
                || $0.username.localizedStandardContains(lowered)
            },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Folders

    func fetchRootFolders() throws -> [Folder] {
        let descriptor = FetchDescriptor<Folder>(
            predicate: #Predicate { $0.parentFolder == nil },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    func save(_ folder: Folder) throws {
        modelContext.insert(folder)
        try modelContext.save()
    }

    func delete(_ folder: Folder) throws {
        // Move child connections to root before deleting
        for connection in folder.connections {
            connection.folder = nil
        }
        // Move subfolders to root
        for subfolder in folder.subfolders {
            subfolder.parentFolder = nil
        }
        modelContext.delete(folder)
        try modelContext.save()
    }

    // MARK: - Tags

    func fetchAllTags() throws -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    func save(_ tag: Tag) throws {
        modelContext.insert(tag)
        try modelContext.save()
    }

    // MARK: - Filtered Queries

    func fetchRecents(limit: Int) throws -> [Connection] {
        var descriptor = FetchDescriptor<Connection>(
            predicate: #Predicate { $0.lastConnectedAt != nil },
            sortBy: [SortDescriptor(\.lastConnectedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func fetchFavorites() throws -> [Connection] {
        let descriptor = FetchDescriptor<Connection>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }
}
