import SwiftUI

/// Renders a recursive `SplitNode` tree into nested split views.
///
/// Uses native SwiftUI `HSplitView` / `VSplitView` to get proper
/// macOS split view behavior with draggable dividers.
struct SplitPaneView: View {
    let node: SplitNode
    let focusedPaneId: UUID?

    @Environment(AppState.self) private var appState

    var body: some View {
        nodeView(for: node)
    }

    /// Renders a node as either a terminal pane or a split container.
    /// Uses `AnyView` type erasure because the function is recursive.
    private func nodeView(for node: SplitNode) -> AnyView {
        switch node {
        case .terminal(let paneId, let sessionId):
            if let activeSession = appState.sessionManager.sessions[sessionId] {
                return AnyView(
                    RDPWorkspaceView(
                        session: activeSession,
                        isFocused: paneId == focusedPaneId
                    )
                )
            } else {
                return AnyView(Color.clear)
            }

        case .split(_, let orientation, let children):
            let childViews = children.map { child in
                nodeView(for: child)
                    .frame(
                        minWidth: orientation == .horizontal ? 200 : nil,
                        minHeight: orientation == .vertical ? 100 : nil
                    )
            }

            switch orientation {
            case .horizontal:
                return AnyView(
                    HSplitView {
                        ForEach(Array(childViews.enumerated()), id: \.offset) { _, view in
                            view
                        }
                    }
                )
            case .vertical:
                return AnyView(
                    VSplitView {
                        ForEach(Array(childViews.enumerated()), id: \.offset) { _, view in
                            view
                        }
                    }
                )
            }
        }
    }
}
