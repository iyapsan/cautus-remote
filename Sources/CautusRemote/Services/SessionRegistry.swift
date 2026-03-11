import Foundation
import SwiftUI
import SwiftData
import CautusRDP

enum SessionPresentation: Hashable {
    case docked
    case detached(windowID: UUID)
}

struct SessionRecord: Identifiable, Hashable {
    let id: UUID
    let connectionID: UUID
    var title: String
    var presentation: SessionPresentation
    
    static func == (lhs: SessionRecord, rhs: SessionRecord) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum SessionPresentationTarget {
    case docked
    case detached
}

@MainActor
@Observable
final class SessionRegistry {
    private(set) var activeSessions: [UUID: SessionRecord] = [:]
    private(set) var activeRuntimes: [UUID: RDPSession] = [:]
    private let keychainService: KeychainService
    
    // Callbacks to decouple presentation focus from the domain layer
    var onFocusDocked: ((UUID) -> Void)?
    var onFocusDetached: ((UUID) -> Void)?
    var onCloseDetachedWindow: ((UUID) -> Void)?
    
    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }
    
    func session(for id: UUID) -> SessionRecord? {
        activeSessions[id]
    }
    
    func existingLiveSession(for connectionID: UUID) -> SessionRecord? {
        activeSessions.values.first { $0.connectionID == connectionID }
    }
    
    func runtime(for id: UUID) -> RDPSession? {
        activeRuntimes[id]
    }
    
    @discardableResult
    func openSession(
        for connection: Connection,
        preferredPresentation: SessionPresentationTarget = .docked,
        reuseIfOpen: Bool = true
    ) -> UUID {
        if reuseIfOpen, let existing = existingLiveSession(for: connection.id) {
            print("[SessionRegistry] Session for \(connection.id) already live. Focusing existing instance.")
            focusSession(existing.id)
            return existing.id
        }
        
        let newSessionID = UUID()
        
        let eff = connection.effectiveRDPConfig(global: .global)
        let configTemplate = RDPConfig(
            host: connection.host,
            port: eff.port,
            user: connection.username,
            pass: "",
            gwHost: connection.gatewayUrl,
            gwUser: connection.gatewayUsername,
            gwPass: nil,
            gwDomain: nil,
            gwMode: eff.gatewayMode.rawValue,
            gwBypassLocal: eff.gatewayBypassLocal,
            gwUseSameCreds: nil,
            ignoreCert: connection.ignoreCertificateErrors
        )
        
        let rdpSession = RDPSession(config: configTemplate)
        let presentation: SessionPresentation = (preferredPresentation == .docked) ? .docked : .detached(windowID: UUID())
        
        let record = SessionRecord(
            id: newSessionID,
            connectionID: connection.id,
            title: connection.name,
            presentation: presentation
        )
        
        activeSessions[newSessionID] = record
        activeRuntimes[newSessionID] = rdpSession
        
        // Start async connection via Keychain
        let keychainSvc = self.keychainService
        let connId = connection.id
        Task.detached {
            do {
                let password = try keychainSvc.retrievePassword(for: connId) ?? ""
                let gwPass = try? keychainSvc.retrievePassword(for: connId)
                
                let realConfig = RDPConfig(
                    host: configTemplate.host,
                    port: configTemplate.port,
                    user: configTemplate.user,
                    pass: password,
                    gwHost: configTemplate.gwHost,
                    gwUser: configTemplate.gwUser,
                    gwPass: gwPass,
                    gwDomain: configTemplate.gwDomain,
                    gwMode: configTemplate.gwMode,
                    gwBypassLocal: configTemplate.gwBypassLocal,
                    gwUseSameCreds: configTemplate.gwUseSameCreds,
                    ignoreCert: configTemplate.ignoreCert
                )
                
                await MainActor.run {
                    rdpSession.updateConfig(realConfig)
                    Task {
                        do {
                            try await rdpSession.connect()
                        } catch {
                            print("[SessionRegistry] Connect failed for \(newSessionID): \(error)")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    print("[SessionRegistry] Keychain failure: \(error)")
                    rdpSession.fail(with: error)
                }
            }
        }
        
        focusSession(newSessionID)
        return newSessionID
    }
    
    func focusSession(_ id: UUID) {
        guard let record = activeSessions[id] else { return }
        switch record.presentation {
        case .docked:
            print("[SessionRegistry] Focusing docked session: \(id)")
            onFocusDocked?(id)
        case .detached(let windowID):
            print("[SessionRegistry] Focusing detached session window: \(windowID)")
            onFocusDetached?(windowID)
        }
    }
    
    func closeSession(_ id: UUID) {
        guard let record = activeSessions[id] else { return }
        print("[SessionRegistry] Terminating session runtime for: \(id)")
        activeRuntimes[id]?.disconnect()
        
        if case .detached(let windowID) = record.presentation {
            onCloseDetachedWindow?(windowID)
        }
        
        activeSessions.removeValue(forKey: id)
        activeRuntimes.removeValue(forKey: id)
        SessionViewCache.shared.remove(for: id)
    }
    
    func moveSessionToDocked(_ id: UUID) {
        guard var record = activeSessions[id] else { return }
        if case .detached(let windowID) = record.presentation {
            onCloseDetachedWindow?(windowID)
        }
        record.presentation = .docked
        activeSessions[id] = record
        focusSession(id)
    }
    
    func moveSessionToDetachedWindow(_ id: UUID) {
        guard var record = activeSessions[id] else { return }
        let windowID = UUID()
        record.presentation = .detached(windowID: windowID)
        activeSessions[id] = record
        focusSession(id)
    }
    
    func closeAll() {
        for id in activeSessions.keys {
            closeSession(id)
        }
    }
}
