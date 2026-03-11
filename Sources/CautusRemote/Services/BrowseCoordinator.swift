import Foundation
import SwiftUI

enum MainSurface: Hashable {
    case browse
    case dockedSession(UUID)
}

@MainActor
@Observable
final class BrowseCoordinator {
    var dockedSessionIDs: [UUID] = []
    var selectedSurface: MainSurface = .browse
    
    private let sessionRegistry: SessionRegistry
    
    init(sessionRegistry: SessionRegistry) {
        self.sessionRegistry = sessionRegistry
        
        self.sessionRegistry.onFocusDocked = { [weak self] id in
            self?.focusDockedSession(id)
        }
    }
    
    func focusBrowse() {
        selectedSurface = .browse
    }
    
    func focusDockedSession(_ id: UUID) {
        if !dockedSessionIDs.contains(id) {
            dockedSessionIDs.append(id)
        }
        selectedSurface = .dockedSession(id)
    }
    
    func removeDockedSession(_ id: UUID) {
        dockedSessionIDs.removeAll { $0 == id }
        if case .dockedSession(let currentId) = selectedSurface, currentId == id {
            // Default to falling back to browse. 
            // In a more complex app we could fall back to the adjacent tab
            focusBrowse()
        }
    }
    
    func selectNextSurface() {
        let allSurfaces: [MainSurface] = [.browse] + dockedSessionIDs.map { .dockedSession($0) }
        guard let currentIndex = allSurfaces.firstIndex(of: selectedSurface) else { return }
        
        let nextIndex = (currentIndex + 1) % allSurfaces.count
        selectedSurface = allSurfaces[nextIndex]
    }
    
    func selectPreviousSurface() {
        let allSurfaces: [MainSurface] = [.browse] + dockedSessionIDs.map { .dockedSession($0) }
        guard let currentIndex = allSurfaces.firstIndex(of: selectedSurface) else { return }
        
        let prevIndex = (currentIndex - 1 + allSurfaces.count) % allSurfaces.count
        selectedSurface = allSurfaces[prevIndex]
    }
    
    func closeCurrentSurface() {
        if case .dockedSession(let id) = selectedSurface {
            // Tell the registry to close the session runtime
            sessionRegistry.closeSession(id)
            removeDockedSession(id)
        }
        // Protective constraint: `.browse` cannot be closed from this action.
    }
    
    /// Synchronize the ordered list in case sessions close externally
    func syncWithRegistry() {
        dockedSessionIDs.removeAll { id in
            guard let record = sessionRegistry.activeSessions[id] else { return true }
            if case .docked = record.presentation {
                return false
            }
            return true
        }
        
        if case .dockedSession(let id) = selectedSurface {
            if !dockedSessionIDs.contains(id) {
                focusBrowse()
            }
        }
    }
}
