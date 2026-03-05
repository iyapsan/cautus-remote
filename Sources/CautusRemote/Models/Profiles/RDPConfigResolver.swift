import Foundation

// MARK: - Folder Chain Builder

/// Builds the folder chain from root to leaf for a given folder.
/// - Pure helper, no SwiftData access after the initial call.
/// - Cycle-guarded: stops if a folder id is seen twice. This "shouldn't happen"
///   but protects against any future SwiftData relationship corruption.
func buildFolderChain(from folder: Folder?) -> [Folder] {
    guard let folder else { return [] }
    var chain: [Folder] = []
    var visited = Set<UUID>()
    var current: Folder? = folder

    // Walk up to root, then reverse so it's root-first
    while let node = current {
        guard !visited.contains(node.id) else {
            // Cycle detected — break. Log in debug builds only.
            assertionFailure("[RDPConfigResolver] Cycle detected in folder chain at id=\(node.id)")
            break
        }
        visited.insert(node.id)
        chain.append(node)
        current = node.parentFolder
    }

    return chain.reversed() // root → leaf
}

// MARK: - Merge Helpers

private extension RDPProfileDefaults {
    /// Overwrite any fields that `overrides` explicitly provides.
    /// nil override fields are left unchanged (inherit from base).
    func applying(_ overrides: RDPOverrides) -> RDPProfileDefaults {
        var result = self
        if let v = overrides.port                 { result.port = v }
        if let v = overrides.colorDepth           { result.colorDepth = v }
        if let v = overrides.enableClipboard      { result.enableClipboard = v }
        if let v = overrides.enableNLA            { result.enableNLA = v }
        if let v = overrides.gatewayMode          { result.gatewayMode = v }
        if let v = overrides.gatewayBypassLocal   { result.gatewayBypassLocal = v }
        if let v = overrides.reconnectMaxAttempts { result.reconnectMaxAttempts = v }
        if let v = overrides.scaling              { result.scaling = v }
        if let v = overrides.dynamicResolution    { result.dynamicResolution = v }
        return result
    }

    /// Merge another full set of defaults on top (folder-level inheritance).
    func merging(_ defaults: RDPProfileDefaults) -> RDPProfileDefaults {
        // Full overwrite — folder defaults replace all base fields.
        return defaults
    }
}

// MARK: - Public API

/// Resolve the effective RDP configuration for a connection.
///
/// Priority (lowest → highest):
///   `global` → folder chain defaults (root first) → connection overrides
///
/// - Parameters:
///   - connection: The connection being opened.
///   - folderChain: Root-to-leaf list of folders. Build with `buildFolderChain(from:)`.
///   - global: App-wide defaults. Pass `AppSettings.rdpDefaults` from the call site;
///             use `.global` only in tests or early v1.
/// - Returns: Fully resolved, validated `RDPProfileDefaults`.
func resolveRDPConfig(
    connection: Connection,
    folderChain: [Folder],
    global: RDPProfileDefaults
) -> RDPProfileDefaults {
    // 1. Start from global baseline.
    var result = global

    // 2. Walk root → leaf: each folder that has explicit defaults overwrites the running result.
    //    NOTE: rdpDefaults decodes JSON — this happens once per connect, not on hot UI paths.
    for folder in folderChain {
        if let folderDefaults = folder.rdpDefaults {
            result = result.merging(folderDefaults)
        }
    }

    // 3. Apply connection-level overrides (only non-nil fields).
    //    rdpOverrides decodes JSON — again, only at connect time.
    result = result.applying(connection.rdpOverrides)

    // 4. Validate/sanitize — prevents profile corruption from bricking connections.
    return result.validated()
}
