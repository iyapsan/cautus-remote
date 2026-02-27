import Foundation

/// High-level service for connection CRUD operations.
///
/// Wraps `ConnectionRepository` and `KeychainService` to provide
/// a clean API for the UI layer. Runs on `@MainActor` to match
/// the repository's isolation domain.
@MainActor
@Observable
final class ConnectionService {
    private let repository: any ConnectionRepository
    private let keychainService: KeychainService

    /// Cached connections for sidebar display
    private(set) var allConnections: [Connection] = []
    private(set) var favorites: [Connection] = []
    private(set) var recents: [Connection] = []
    private(set) var rootFolders: [Folder] = []
    private(set) var allTags: [Tag] = []

    /// Incremented on every loadAll() to force SwiftUI re-render
    private(set) var dataVersion: Int = 0

    /// Connections not assigned to any folder
    var unfiledConnections: [Connection] {
        allConnections.filter { $0.folder == nil }
    }

    /// Connections in a specific folder (derived from allConnections for reliable observation)
    func connectionsInFolder(_ folder: Folder) -> [Connection] {
        allConnections.filter { $0.folder?.id == folder.id }
    }

    init(repository: any ConnectionRepository, keychainService: KeychainService = KeychainService()) {
        self.repository = repository
        self.keychainService = keychainService
    }

    // MARK: - Data Loading

    /// Refresh all cached data from the repository.
    func loadAll() throws {
        allConnections = try repository.fetchAll()
        favorites = try repository.fetchFavorites()
        recents = try repository.fetchRecents(limit: 10)
        rootFolders = try repository.fetchRootFolders()
        allTags = try repository.fetchAllTags()
        dataVersion += 1
    }

    // MARK: - Connection Operations

    /// Save a connection and optionally store its password and folder.
    func save(_ connection: Connection, password: String?, folder: Folder? = nil) throws {
        try repository.save(connection)

        // Set folder AFTER insert so SwiftData manages the relationship on context objects
        if connection.folder?.id != folder?.id {
            connection.folder = folder
            try repository.save(connection)
        }

        if let password, !password.isEmpty {
            try keychainService.storePassword(password, for: connection.id)
        }
        try loadAll()
    }

    /// Delete a connection and its Keychain credentials.
    func delete(_ connection: Connection) throws {
        try keychainService.deleteAll(for: connection.id)
        try repository.delete(connection)
        try loadAll()
    }

    /// Toggle favorite status for a connection.
    func toggleFavorite(_ connection: Connection) throws {
        connection.isFavorite.toggle()
        connection.updatedAt = .now
        try repository.save(connection)
        try loadAll()
    }

    /// Update the last connected timestamp.
    func markConnected(_ connection: Connection) throws {
        connection.lastConnectedAt = .now
        connection.updatedAt = .now
        try repository.save(connection)
        try loadAll()
    }

    // MARK: - Folder Operations

    func saveFolder(_ folder: Folder) throws {
        try repository.save(folder)
        try loadAll()
    }

    func deleteFolder(_ folder: Folder) throws {
        try repository.delete(folder)
        try loadAll()
    }

    func createFolder(name: String, parent: Folder? = nil) throws {
        let folder = Folder(name: name, parent: parent)
        folder.sortOrder = (parent?.subfolders.count ?? rootFolders.count)
        try repository.save(folder)
        try loadAll()
    }

    func moveConnection(_ connection: Connection, to folder: Folder?) throws {
        connection.folder = folder
        connection.updatedAt = .now
        try repository.save(connection)
        try loadAll()
    }

    /// Flattened list of all folders for picker display
    func allFoldersFlattened() -> [(folder: Folder, depth: Int)] {
        var result: [(Folder, Int)] = []
        func walk(_ folders: [Folder], depth: Int) {
            for f in folders.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                result.append((f, depth))
                walk(f.subfolders, depth: depth + 1)
            }
        }
        walk(rootFolders, depth: 0)
        return result
    }

    // MARK: - Tag Operations

    func saveTag(_ tag: Tag) throws {
        try repository.save(tag)
        try loadAll()
    }

    // MARK: - Search

    func search(query: String) throws -> [Connection] {
        guard !query.isEmpty else { return allConnections }
        return try repository.search(query: query)
    }
}
