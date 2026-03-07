import SwiftUI
import CautusRDP
import Foundation

enum InspectorSelection: Equatable {
    case none
    case globalDefaults
    case folder(UUID)
    case connection(UUID)
}

@MainActor
class MainWindowViewModel: ObservableObject {
    @Published var mainContentSelection: MainContentSelection = .welcome
    @Published var inspectorSelection: InspectorSelection = .none
    @Published var inspectorVisible: Bool = true
}
