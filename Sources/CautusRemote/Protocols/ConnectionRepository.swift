import Foundation

/// Persistence abstraction for connections, folders, and tags.
///
/// v1 is backed by `SwiftDataRepository`. This protocol allows future
/// migration to GRDB, raw SQLite, or Core Data without changing
/// business logic or UI code.
///
/// All operations run on `@MainActor` because SwiftData model objects
/// are not `Sendable` and must be accessed from a single isolation domain.
@MainActor
protocol ConnectionRepository {
    // MARK: - Connections

    /// Fetch all connections, ordered by name.
    func fetchAll() throws -> [Connection]

    /// Fetch a single connection by ID.
    func fetch(id: UUID) throws -> Connection?

    /// Create or update a connection.
    func save(_ connection: Connection) throws

    /// Delete a connection and its Keychain credentials.
    func delete(_ connection: Connection) throws

    /// Search connections by name or host.
    func search(query: String) throws -> [Connection]

    // MARK: - Folders

    /// Fetch root-level folders (no parent).
    func fetchRootFolders() throws -> [Folder]

    /// Create or update a folder.
    func save(_ folder: Folder) throws

    /// Delete a folder. Connections inside are moved to root.
    func delete(_ folder: Folder) throws

    // MARK: - Tags

    /// Fetch all tags.
    func fetchAllTags() throws -> [Tag]

    /// Create or update a tag.
    func save(_ tag: Tag) throws

    // MARK: - Filtered Queries

    /// Fetch recently connected connections.
    func fetchRecents(limit: Int) throws -> [Connection]

    /// Fetch all favorited connections.
    func fetchFavorites() throws -> [Connection]
}
