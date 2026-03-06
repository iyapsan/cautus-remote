import Foundation

// MARK: - Folder Chain Builder

/// Builds the root-first folder chain for a given folder.
///
/// - Single canonical implementation. Do NOT duplicate this logic in UI or resolver layers.
/// - Cycle-guarded: stops if a folder id is seen twice (protects against SwiftData corruption).
/// - Returns `[]` when `folder` is nil (connection has no folder).
func buildFolderChain(for folder: Folder?) -> [Folder] {
    guard let folder else { return [] }
    var chain: [Folder] = []
    var visited = Set<UUID>()
    var current: Folder? = folder

    // Walk leaf → root, collect, then reverse
    while let node = current {
        guard !visited.contains(node.id) else {
            assertionFailure("[RDPConfigResolver] Cycle detected in folder chain at id=\(node.id)")
            break
        }
        visited.insert(node.id)
        chain.append(node)
        current = node.parentFolder
    }

    return chain.reversed() // root → leaf
}

// MARK: - Public Resolver

/// Resolve the effective RDP configuration for a connection.
///
/// Priority (lowest → highest):
///   `global` → folder patches (root first) → connection patch
///
/// - Parameters:
///   - global: App-wide concrete baseline. Use `AppSettings.rdpDefaults` in production;
///             `.global` in tests / early v1.
///   - folderChain: Root-to-leaf folder list. Build with `buildFolderChain(for:)`.
///   - connectionPatch: Connection-level patch, or nil if the connection has no overrides.
/// - Returns: Fully resolved, validated `RDPResolvedConfig`.
///
/// - Note: Decodes JSON blobs inside Folder/Connection at call time.
///   Call only at connect time or when opening an editor — NOT during list rendering.
func resolveRDPConfig(
    global: RDPResolvedConfig,
    folderChain: [Folder],
    connectionPatch: RDPPatch?
) -> RDPResolvedConfig {
    // 1. Start from concrete global baseline
    var result = global

    // 2. Apply each folder's patch (root → leaf). Each patch overwrites only non-nil fields.
    //    A folder with rdpPatch == nil contributes nothing (full inherit).
    for folder in folderChain {
        if let patch = folder.rdpPatch {
            result = result.applying(patch)
        }
    }

    // 3. Apply connection-level patch if present.
    //    nil connectionPatch == no overrides == result is unchanged.
    if let patch = connectionPatch {
        result = result.applying(patch)
    }

    // 4. Clamp / validate before handing off to the engine
    return result.validated()
}
