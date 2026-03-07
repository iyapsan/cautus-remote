import SwiftUI

struct FolderSummaryView: View {
    let folder: Folder
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Label(folder.name, systemImage: "folder.fill")
                    .font(.title)
                    .fontWeight(.semibold)
                
                let stats = contentStats()
                Text(stats)
                    .foregroundStyle(.secondary)
            }
            
            // Adaptive Quick Actions
            HStack(spacing: 10) {
                Button {
                    appState.folderActionTarget = folder
                    appState.folderAlertText = ""
                    appState.isShowingNewFolderAlert = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                
                Button {
                    appState.editingConnection = nil
                    appState.isShowingConnectionSheet = true
                } label: {
                    Label("New Connection", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                
                if !appState.connectionService.connectionsInFolder(folder).isEmpty {
                    Button("Connect All") {
                        // Action implemented later
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Content Sections
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if folder.subfolders.isEmpty && appState.connectionService.connectionsInFolder(folder).isEmpty {
                        // Empty State
                        VStack(spacing: 12) {
                            Image(systemName: "folder")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                            Text("This folder is empty")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                    } else {
                        // Subfolders Section
                        if !folder.subfolders.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Folders")
                                    .font(.headline)
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)], spacing: 16) {
                                    ForEach(folder.subfolders.sorted(by: { $0.sortOrder < $1.sortOrder })) { subfolder in
                                        HStack {
                                            Image(systemName: "folder.fill")
                                                .foregroundStyle(.blue)
                                                .font(.title2)
                                            Text(subfolder.name)
                                                .fontWeight(.medium)
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                                    }
                                }
                            }
                        }
                        
                        // Connections Section
                        let connections = appState.connectionService.connectionsInFolder(folder)
                        if !connections.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Connections")
                                    .font(.headline)
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 350), spacing: 16)], spacing: 16) {
                                    ForEach(Array(connections)) { connection in
                                        HStack(spacing: 12) {
                                            Image(systemName: "desktopcomputer")
                                                .font(.title2)
                                                .foregroundStyle(.secondary)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(connection.name)
                                                    .fontWeight(.medium)
                                                Text(connection.displayAddress)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            
                                            Text("RDP")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.15))
                                                .foregroundStyle(.blue)
                                                .clipShape(Capsule())
                                        }
                                        .padding()
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private func contentStats() -> String {
        let fCount = folder.subfolders.count
        let cCount = appState.connectionService.connectionsInFolder(folder).count
        
        if fCount == 0 && cCount == 0 {
            return "0 items"
        }
        
        var parts: [String] = []
        if fCount > 0 {
            parts.append("\(fCount) folder\(fCount == 1 ? "" : "s")")
        }
        if cCount > 0 {
            parts.append("\(cCount) connection\(cCount == 1 ? "" : "s")")
        }
        
        return parts.joined(separator: ", ")
    }
}
