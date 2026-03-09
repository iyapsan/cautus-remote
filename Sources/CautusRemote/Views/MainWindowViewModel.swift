import SwiftUI
import CautusRDP
import Foundation

enum InspectorSelection: Equatable {
    case none
    case globalDefaults
    case folder(UUID)
    case connection(UUID)
}

enum BrowserContentSelection: Equatable {
    case welcome
    case folder(UUID)
    case connection(UUID)
    case search(String)
}

@MainActor
class MainWindowViewModel: ObservableObject {
    @Published var browserSelection: BrowserContentSelection = .welcome
    @Published var inspectorSelection: InspectorSelection = .none
    @Published var inspectorVisible: Bool = true
    @Published var browserSearchQuery: String = ""
}
