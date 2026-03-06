import Testing
import Foundation
@testable import CautusRemote

// MARK: - Test Helpers

/// Lightweight test resolver using `RDPResolvedConfig.applying(:)` directly —
/// the same logic production uses, without needing SwiftData Folder objects.
private func resolve(
    global: RDPResolvedConfig = .global,
    folderPatches: [RDPPatch?] = [],
    connectionPatch: RDPPatch? = nil
) -> RDPResolvedConfig {
    var result = global
    for patch in folderPatches {
        if let patch { result = result.applying(patch) }
    }
    if let patch = connectionPatch { result = result.applying(patch) }
    return result.validated()
}

// MARK: - Tests

struct ProfileResolutionTests {

    // ✅ No patches anywhere → falls back to .global
    @Test func noPatches_usesGlobal() {
        let eff = resolve()
        #expect(eff == RDPResolvedConfig.global.validated())
        #expect(eff.port == 3389)
        #expect(eff.clipboardEnabled == true)
        #expect(eff.nlaRequired == true)
        #expect(eff.reconnectAttempts == 5)
    }

    // ✅ Single folder patch overrides only the fields it sets; others stay global
    @Test func singleFolderPatch_overridesOnlySetFields() {
        let folderPatch = RDPPatch(port: 3390, clipboardEnabled: false)
        let eff = resolve(folderPatches: [folderPatch])
        #expect(eff.port == 3390)              // patched by folder
        #expect(eff.clipboardEnabled == false) // patched by folder
        #expect(eff.nlaRequired == true)       // unchanged — stays global
        #expect(eff.scaling == .fit)           // unchanged — stays global
    }

    // ✅ Child folder patch overrides parent patch for ONE field only
    @Test func childFolderPatch_overridesParentForOneFieldOnly() {
        let parentPatch = RDPPatch(port: 3390, nlaRequired: false)
        let childPatch = RDPPatch(port: 3391)  // only port; no NLA override
        // Root-first order: [parentPatch, childPatch]
        let eff = resolve(folderPatches: [parentPatch, childPatch])
        #expect(eff.port == 3391)          // child wins on port
        #expect(eff.nlaRequired == false)  // parent patch still applied (child didn't set NLA)
    }

    // ✅ Connection patch wins over folder chain
    @Test func connectionPatch_winsOverFolderChain() {
        let folderPatch = RDPPatch(port: 3390, clipboardEnabled: false)
        let connPatch = RDPPatch(port: 9999, clipboardEnabled: true)
        let eff = resolve(folderPatches: [folderPatch], connectionPatch: connPatch)
        #expect(eff.port == 9999)             // connection wins
        #expect(eff.clipboardEnabled == true) // connection wins
    }

    // ✅ nil fields in connection patch do NOT clobber folder chain values
    @Test func nilPatchFields_doNotClobberParent() {
        let folderPatch = RDPPatch(clipboardEnabled: false)
        let connPatch = RDPPatch(port: 3399, clipboardEnabled: nil) // explicitly nil (inherit)
        let eff = resolve(folderPatches: [folderPatch], connectionPatch: connPatch)
        #expect(eff.port == 3399)              // set by connection
        #expect(eff.clipboardEnabled == false) // inherited from folder, not clobbered
    }

    // ✅ Empty (nil) connection patch leaves resolved config unchanged
    @Test func nilConnectionPatch_leavesResolutionUnchanged() {
        let folderPatch = RDPPatch(port: 3390)
        let withNil = resolve(folderPatches: [folderPatch], connectionPatch: nil)
        let withEmpty = resolve(folderPatches: [folderPatch], connectionPatch: RDPPatch())
        // Both should produce identical results — nil patch == empty patch
        #expect(withNil == withEmpty)
        #expect(withNil.port == 3390)
    }

    // ✅ validated() clamps port 0 → 1
    @Test func validation_clampsPortLow() {
        var cfg = RDPResolvedConfig()
        cfg.port = 0
        #expect(cfg.validated().port == 1)
    }

    // ✅ validated() clamps port 99999 → 65535
    @Test func validation_clampsPortHigh() {
        var cfg = RDPResolvedConfig()
        cfg.port = 99999
        #expect(cfg.validated().port == 65535)
    }

    // ✅ validated() clamps reconnectAttempts -1 → 0
    @Test func validation_clampsReconnectsLow() {
        var cfg = RDPResolvedConfig()
        cfg.reconnectAttempts = -1
        #expect(cfg.validated().reconnectAttempts == 0)
    }

    // ✅ validated() clamps reconnectAttempts 999 → 20
    @Test func validation_clampsReconnectsHigh() {
        var cfg = RDPResolvedConfig()
        cfg.reconnectAttempts = 999
        #expect(cfg.validated().reconnectAttempts == 20)
    }

    // ✅ diff(from:) returns only changed fields (on resolved configs, not patches)
    @Test func diff_showsOnlyChangedFields() {
        var a = RDPResolvedConfig()
        a.port = 3390
        a.clipboardEnabled = false
        let b = RDPResolvedConfig() // unchanged global
        let diffs = a.diff(from: b)
        let keys = diffs.map { $0.key }
        #expect(keys.contains("Port"))
        #expect(keys.contains("Clipboard Sharing"))
        #expect(!keys.contains("NLA"))
        #expect(!keys.contains("Scaling"))
    }

    // ✅ RDPPatch.isEmpty
    @Test func patch_isEmpty() {
        #expect(RDPPatch().isEmpty == true)
        #expect(RDPPatch(port: 3390).isEmpty == false)
    }

    // ✅ buildFolderChain(for:) returns root-first order, cycle-safe
    @Test func folderChainBuilder_rootFirstOrder() {
        let root = Folder(name: "Root")
        let child = Folder(name: "Child", parent: root)
        let chain = buildFolderChain(for: child)
        #expect(chain.count == 2)
        #expect(chain.first?.name == "Root")
        #expect(chain.last?.name == "Child")
    }
}
