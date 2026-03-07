import Foundation

enum MainContentSelection: Equatable {
    case welcome
    case folder(UUID)
    case connection(UUID)
    case workspace
}
