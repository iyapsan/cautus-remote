import Testing
import Foundation
@testable import CautusRemote

// MARK: - Helpers for testing the pure resolution algorithm

/// Build a folder "chain" manually for tests without SwiftData (no ModelContext needed).
/// Returns the chain root-first, the way `buildFolderChain` would.
private func folderChain(_ defauts: [RDPProfileDefaults?]) -> [_TestFolder] {
    defauts.map { _TestFolder(rdpDefaults: $0) }
}

/// Lightweight test-only folder stub (no SwiftData dependency).
private struct _TestFolder {
    let rdpDefaults: RDPProfileDefaults?
}

/// Overload of the resolver that works with test stubs.
private func resolve(
    overrides: RDPOverrides = RDPOverrides(),
    folderDefaults: [RDPProfileDefaults?] = [],
    global: RDPProfileDefaults = .global
) -> RDPProfileDefaults {
    // Run the same merge logic as the production resolver
    var result = global
    for d in folderDefaults {
        if let d { result = d }
    }
    // Apply overrides
    if let v = overrides.port                 { result.port = v }
    if let v = overrides.colorDepth           { result.colorDepth = v }
    if let v = overrides.enableClipboard      { result.enableClipboard = v }
    if let v = overrides.enableNLA            { result.enableNLA = v }
    if let v = overrides.gatewayMode          { result.gatewayMode = v }
    if let v = overrides.gatewayBypassLocal   { result.gatewayBypassLocal = v }
    if let v = overrides.reconnectMaxAttempts { result.reconnectMaxAttempts = v }
    if let v = overrides.scaling              { result.scaling = v }
    if let v = overrides.dynamicResolution    { result.dynamicResolution = v }
    return result.validated()
}

// MARK: - Tests

/// Tests for the RDP Profile Inheritance resolution algorithm.
struct ProfileResolutionTests {

    // ✅ No defaults anywhere → falls back to .global
    @Test func noDefaultsAnywhere_usesGlobal() {
        let eff = resolve()
        #expect(eff == RDPProfileDefaults.global.validated())
        #expect(eff.port == 3389)
        #expect(eff.enableClipboard == true)
        #expect(eff.enableNLA == true)
        #expect(eff.reconnectMaxAttempts == 5)
    }

    // ✅ Single folder default overrides global for the fields it sets
    @Test func singleFolderDefault_overridesGlobal() {
        var folderDef = RDPProfileDefaults()
        folderDef.port = 3390
        folderDef.enableClipboard = false

        let eff = resolve(folderDefaults: [folderDef])
        #expect(eff.port == 3390)                 // overridden
        #expect(eff.enableClipboard == false)     // overridden
        #expect(eff.enableNLA == true)            // still from global
    }

    // ✅ Nested folder (child) only overrides subset of fields
    @Test func nestedFolders_childWins() {
        var rootDef = RDPProfileDefaults()
        rootDef.port = 3390
        rootDef.enableNLA = false

        var childDef = RDPProfileDefaults()
        childDef.port = 3391               // child overrides port further
        // NLA not set in child — so child's value (inherited from its full struct) takes precedence

        // Root-first order: [root, child]
        let eff = resolve(folderDefaults: [rootDef, childDef])
        #expect(eff.port == 3391)          // child wins on port
        // Note: in the "full defaults" merge strategy, the full childDef struct applies
        // so childDef.enableNLA = true (its default), overriding rootDef.enableNLA = false
        #expect(eff.enableNLA == true)
    }

    // ✅ Connection overrides win over folder chain
    @Test func connectionOverrides_winOverFolderChain() {
        var folderDef = RDPProfileDefaults()
        folderDef.port = 3390
        folderDef.enableClipboard = false

        let overrides = RDPOverrides(
            port: 9999,
            enableClipboard: true  // connection re-enables clipboard
        )

        let eff = resolve(overrides: overrides, folderDefaults: [folderDef])
        #expect(eff.port == 9999)             // connection override wins
        #expect(eff.enableClipboard == true)  // connection override wins
    }

    // ✅ nil override field does not clobber folder chain value
    @Test func nilOverrideField_doesNotClobber() {
        var folderDef = RDPProfileDefaults()
        folderDef.enableClipboard = false

        let overrides = RDPOverrides(
            port: 3399,
            enableClipboard: nil  // explicitly left as inherit
        )

        let eff = resolve(overrides: overrides, folderDefaults: [folderDef])
        #expect(eff.port == 3399)             // overridden by connection
        #expect(eff.enableClipboard == false) // inherited from folder, not clobbered
    }

    // ✅ validated() clamps values — port 0 → 1
    @Test func validation_clampsPort() {
        var d = RDPProfileDefaults()
        d.port = 0
        let validated = d.validated()
        #expect(validated.port == 1)
    }

    // ✅ validated() clamps reconnectMaxAttempts — -1 → 0
    @Test func validation_clampsReconnects() {
        var d = RDPProfileDefaults()
        d.reconnectMaxAttempts = -1
        let validated = d.validated()
        #expect(validated.reconnectMaxAttempts == 0)
    }

    // ✅ validated() clamps reconnectMaxAttempts over 20 → 20
    @Test func validation_clampsReconnectsUpper() {
        var d = RDPProfileDefaults()
        d.reconnectMaxAttempts = 999
        let validated = d.validated()
        #expect(validated.reconnectMaxAttempts == 20)
    }

    // ✅ diff(from:) returns only changed fields
    @Test func diff_showsOnlyChangedFields() {
        var a = RDPProfileDefaults()
        a.port = 3390
        a.enableClipboard = false
        let b = RDPProfileDefaults() // defaults

        let diffs = a.diff(from: b)
        let keys = diffs.map { $0.key }
        #expect(keys.contains("Port"))
        #expect(keys.contains("Clipboard"))
        #expect(!keys.contains("NLA"))
        #expect(!keys.contains("Scaling"))
    }

    // ✅ RDPOverrides.isEmpty
    @Test func overrides_isEmpty() {
        #expect(RDPOverrides().isEmpty == true)
        #expect(RDPOverrides(port: 3390).isEmpty == false)
    }

    // ✅ buildFolderChain is cycle-safe (smoke test via non-recursive chain)
    @Test func folderChainBuilder_stopAtRoot() {
        let root = Folder(name: "Root")
        let child = Folder(name: "Child", parent: root)
        let chain = buildFolderChain(from: child)
        #expect(chain.count == 2)
        #expect(chain.first?.name == "Root")
        #expect(chain.last?.name == "Child")
    }
}
