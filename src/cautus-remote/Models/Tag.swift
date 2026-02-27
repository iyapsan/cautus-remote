import Foundation
import SwiftData

/// Flexible label for categorizing connections.
@Model
final class Tag {
    @Attribute(.unique)
    var id: UUID

    var name: String

    /// Display color as hex string (e.g. "4A90D9")
    var colorHex: String

    /// Connections associated with this tag (inverse set on Connection.tags)
    var connections: [Connection]

    init(name: String, colorHex: String = "4A90D9") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.connections = []
    }
}
