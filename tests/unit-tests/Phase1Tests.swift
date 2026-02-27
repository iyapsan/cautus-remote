import Testing
import Foundation
@testable import CautusRemote

/// Tests for domain models and utility functions.
struct ModelTests {
    @Test func connectionDefaults() async throws {
        let conn = Connection(name: "Test Server", host: "192.168.1.1", username: "admin")
        #expect(conn.port == 22)
        #expect(conn.authMethod == .password)
        #expect(conn.isFavorite == false)
        #expect(conn.keepaliveInterval == 60)
        #expect(conn.connectionTimeout == 30)
        #expect(conn.scrollbackLines == 10000)
        #expect(conn.environmentVars.isEmpty)
        #expect(conn.displayAddress == "admin@192.168.1.1")
    }

    @Test func connectionCustomPort() async throws {
        let conn = Connection(name: "Custom Port", host: "example.com", port: 2222, username: "user")
        #expect(conn.displayAddress == "user@example.com:2222")
    }

    @Test func connectionAuthMethodRoundtrip() async throws {
        let conn = Connection(name: "Key Auth", host: "example.com", username: "user", authMethod: .publicKey)
        #expect(conn.authMethod == .publicKey)
        #expect(conn.authMethodRaw == "publicKey")
        conn.authMethod = .password
        #expect(conn.authMethodRaw == "password")
    }

    @Test func folderHierarchy() async throws {
        let root = Folder(name: "Production")
        let child = Folder(name: "Web Servers", parent: root)
        #expect(root.isRoot)
        #expect(!child.isRoot)
        #expect(child.parentFolder?.name == "Production")
    }

    @Test func tagCreation() async throws {
        let tag = Tag(name: "critical")
        #expect(tag.name == "critical")
        #expect(tag.connections.isEmpty)
    }

    @Test func sessionStateEquality() async throws {
        #expect(SessionState.idle == SessionState.idle)
        #expect(SessionState.connected == SessionState.connected)
        #expect(SessionState.reconnecting(attempt: 1) == SessionState.reconnecting(attempt: 1))
        #expect(SessionState.reconnecting(attempt: 1) != SessionState.reconnecting(attempt: 2))
    }

    @Test func sessionStateStatusColors() async throws {
        #expect(SessionState.connected.statusColor == .green)
        #expect(SessionState.reconnecting(attempt: 1).statusColor == .yellow)
        #expect(SessionState.failed(SessionError(code: .timeout, message: "")).statusColor == .red)
        #expect(SessionState.idle.statusColor == .none)
    }

    @Test func sessionStateIsActive() async throws {
        #expect(SessionState.connecting.isActive)
        #expect(SessionState.connected.isActive)
        #expect(SessionState.reconnecting(attempt: 1).isActive)
        #expect(!SessionState.idle.isActive)
        #expect(!SessionState.disconnected.isActive)
    }
}

struct FuzzySearchTests {
    @Test func exactMatch() async throws {
        let score = FuzzySearch.score(query: "server", candidate: "server")
        #expect(score > 0.9)
    }

    @Test func prefixMatch() async throws {
        let score = FuzzySearch.score(query: "serv", candidate: "server-01")
        #expect(score > 0.7)
    }

    @Test func containsMatch() async throws {
        let score = FuzzySearch.score(query: "01", candidate: "server-01")
        #expect(score > 0.4)
    }

    @Test func fuzzyMatch() async throws {
        let score = FuzzySearch.score(query: "svr", candidate: "server")
        #expect(score > 0.2)
    }

    @Test func noMatch() async throws {
        let score = FuzzySearch.score(query: "xyz", candidate: "server")
        #expect(score == 0)
    }

    @Test func favoriteBoost() async throws {
        let normal = FuzzySearch.score(query: "serv", candidate: "server")
        let fav = FuzzySearch.score(query: "serv", candidate: "server", isFavorite: true)
        #expect(fav > normal)
    }

    @Test func emptyQuery() async throws {
        let score = FuzzySearch.score(query: "", candidate: "anything")
        #expect(score > 0)
    }
}

struct SplitPaneTests {
    @Test func singlePaneCount() async throws {
        let node = SplitNode.terminal(id: UUID(), sessionId: UUID())
        #expect(node.paneCount == 1)
        #expect(node.canSplit)
    }

    @Test func splitPaneCount() async throws {
        let node = SplitNode.split(
            id: UUID(),
            orientation: .horizontal,
            children: [
                .terminal(id: UUID(), sessionId: UUID()),
                .terminal(id: UUID(), sessionId: UUID()),
            ]
        )
        #expect(node.paneCount == 2)
        #expect(node.canSplit)
    }

    @Test func maxPanesReached() async throws {
        let node = SplitNode.split(
            id: UUID(),
            orientation: .horizontal,
            children: [
                .split(id: UUID(), orientation: .vertical, children: [
                    .terminal(id: UUID(), sessionId: UUID()),
                    .terminal(id: UUID(), sessionId: UUID()),
                ]),
                .split(id: UUID(), orientation: .vertical, children: [
                    .terminal(id: UUID(), sessionId: UUID()),
                    .terminal(id: UUID(), sessionId: UUID()),
                ]),
            ]
        )
        #expect(node.paneCount == 4)
        #expect(!node.canSplit)
    }

    @Test func allTerminalIdsOrdering() async throws {
        let id1 = UUID(), id2 = UUID(), id3 = UUID()
        let node = SplitNode.split(
            id: UUID(),
            orientation: .horizontal,
            children: [
                .terminal(id: id1, sessionId: UUID()),
                .split(id: UUID(), orientation: .vertical, children: [
                    .terminal(id: id2, sessionId: UUID()),
                    .terminal(id: id3, sessionId: UUID()),
                ]),
            ]
        )
        let ids = node.allTerminalIds
        #expect(ids == [id1, id2, id3])
    }
}
