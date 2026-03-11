import SwiftUI
import AppKit

struct DockedSessionSwitcherView: View {
    @Environment(BrowseCoordinator.self) private var browseCoordinator
    @Environment(SessionRegistry.self) private var sessionRegistry
    @Environment(DetachedSessionWindowManager.self) private var detachedManager
    
    var body: some View {
        if !browseCoordinator.dockedSessionIDs.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("ACTIVE SESSIONS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                        
                    SwitcherTab(
                        id: nil,
                        title: "Browse",
                        icon: "magnifyingglass",
                        isSelected: browseCoordinator.selectedSurface == .browse,
                        action: { browseCoordinator.focusBrowse() },
                        closeAction: nil,
                        detachAction: nil
                    )
                    
                    ForEach(browseCoordinator.dockedSessionIDs, id: \.self) { id in
                        let record = sessionRegistry.session(for: id)
                        SwitcherTab(
                            id: id,
                            title: record?.title ?? "Session",
                            icon: "server.rack",
                            isSelected: browseCoordinator.selectedSurface == .dockedSession(id),
                            action: { browseCoordinator.focusDockedSession(id) },
                            closeAction: {
                                sessionRegistry.closeSession(id)
                                browseCoordinator.removeDockedSession(id)
                            },
                            detachAction: {
                                browseCoordinator.removeDockedSession(id)
                                sessionRegistry.moveSessionToDetachedWindow(id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
    }
}

private struct SwitcherTab: View {
    let id: UUID?
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    let closeAction: (() -> Void)?
    let detachAction: (() -> Void)?
    
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                
                if let closeAction {
                    Button(action: closeAction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isHovering ? .primary : .secondary)
                            .padding(3)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovering || isSelected ? 1 : 0)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isDragging
                        ? Color.accentColor.opacity(0.25)
                        : isSelected
                            ? Color.accentColor.opacity(0.15)
                            : isHovering ? Color.secondary.opacity(0.1) : Color.clear)
            )
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .shadow(color: isDragging ? Color.black.opacity(0.2) : .clear, radius: 6, y: 3)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        // Context menu for detach and close
        .contextMenu {
            if let detachAction {
                Button {
                    detachAction()
                } label: {
                    Label("Move to New Window", systemImage: "arrow.up.forward.app")
                }
            }
            if let closeAction {
                Divider()
                Button(role: .destructive) {
                    closeAction()
                } label: {
                    Label("Close Session", systemImage: "xmark")
                }
            }
        }
        // Drag-to-detach: drag the tab far enough out of the bar to pop it into a new window
        .gesture(
            detachAction != nil
                ? DragGesture(minimumDistance: 20, coordinateSpace: .global)
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        isDragging = false
                        dragOffset = .zero
                        // If dragged more than 80pt downward (out of the bar), detach
                        if value.translation.height > 80 {
                            detachAction?()
                        }
                    }
                : nil
        )
    }
}
