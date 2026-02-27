import Foundation
import UniformTypeIdentifiers
import CoreTransferable

extension UTType {
    /// Custom UTType for dragging connection IDs within the app.
    static let connectionID = UTType(exportedAs: "com.cautusremote.connection-id")
}

/// Lightweight Transferable wrapper for dragging connections by ID.
/// SwiftData @Model classes can't conform to Codable directly,
/// so we use this thin struct as the drag payload.
struct ConnectionTransfer: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .connectionID)
    }
}
