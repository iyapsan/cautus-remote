import SwiftUI
import CautusRDP
import Foundation

enum InspectorSelection: Equatable {
    case none
    case globalDefaults
    case folder(UUID)
    case connection(UUID)
}

enum BrowseContentSelection: Equatable {
    case welcome
    case folder(UUID)
    case connection(UUID)
    case emptyState
    case search(String)
}

enum WindowTabKind: Equatable, Hashable, Codable {
    case browse
    case session(UUID)
}

@MainActor
class MainWindowViewModel: ObservableObject {
    let listId = UUID()
    @Published var selectedTabKind: WindowTabKind = .browse
    @Published var browseContentSelection: BrowseContentSelection = .welcome
    @Published var inspectorSelection: InspectorSelection = .none
    @Published var inspectorVisible: Bool = true
    @Published var browserSearchQuery: String = ""
}
