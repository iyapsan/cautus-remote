import SwiftUI
import CautusRDP

struct ConnectionSummaryView: View {
    let connection: Connection
    @Environment(AppState.self) private var appState

    // Resolve effective configuration to show read-only stats
    private var config: RDPResolvedConfig {
        var chain: [Folder] = []
        var f = connection.folder
        while let folder = f { chain.append(folder); f = folder.parentFolder }
        
        return resolveRDPConfig(
            global: .global,
            folderChain: chain.reversed(),
            connectionPatch: connection.rdpPatch
        )
    }

    var body: some View {
        VStack(spacing: 32) {
            // Header Identity
            VStack(spacing: 16) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                
                VStack(spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(connection.name)
                            .font(.title)
                            .fontWeight(.semibold)
                        
                        Text("RDP")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                    
                    Text(connection.displayAddress)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    if !connection.username.isEmpty {
                        Text("as \(connection.username)")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            // Primary Actions
            HStack(spacing: 16) {
                Button {
                    Task { await openConnection() }
                } label: {
                    Label("Connect", systemImage: "play.fill")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button {
                    let newName = "\(connection.name) copy"
                    let duplicate = Connection(
                        name: newName,
                        host: connection.host,
                        port: connection.port,
                        username: connection.username,
                        gatewayUrl: connection.gatewayUrl,
                        gatewayUsername: connection.gatewayUsername,
                        ignoreCertificateErrors: connection.ignoreCertificateErrors
                    )
                    duplicate.folder = connection.folder
                    if let origPatch = connection.rdpPatch {
                        duplicate.rdpPatch = origPatch
                    }
                    try? appState.connectionService.save(duplicate, password: nil)
                    // Select the newly duplicated item
                    appState.sidebar.selectedConnectionIds = [duplicate.id]
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            Divider()
                .frame(width: 300)
                .opacity(0.5)
            
            // Effective Configuration Summary (Read-Only)
            VStack(alignment: .leading, spacing: 16) {
                Text("Effective Configuration")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [GridItem(.fixed(140), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], spacing: 12) {
                    
                    // Port
                    Text("Port")
                        .foregroundStyle(.secondary)
                    Text("\(config.port)")
                        .fontWeight(.medium)
                    
                    // Gateway
                    Text("RD Gateway")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        let hasGateway = !(connection.gatewayUrl ?? "").isEmpty
                        Image(systemName: hasGateway ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(hasGateway ? .green : .red)
                        Text(hasGateway ? connection.gatewayUrl! : "Disabled")
                            .fontWeight(.medium)
                    }
                    
                    // Clipboard
                    Text("Clipboard")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: config.clipboardEnabled ? "doc.on.clipboard.fill" : "xmark.circle.fill")
                            .foregroundStyle(config.clipboardEnabled ? .blue : .secondary)
                        Text(config.clipboardEnabled ? "Enabled" : "Disabled")
                            .fontWeight(.medium)
                    }
                    
                    // Audio
                    Text("Audio")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        let audioIcon = config.audioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
                        let audioColor: Color = config.audioEnabled ? .blue : .secondary
                        let audioText = config.audioEnabled ? "Play on this Mac" : "Do not play"
                        
                        Image(systemName: audioIcon)
                            .foregroundStyle(audioColor)
                        Text(audioText)
                            .fontWeight(.medium)
                    }
                }
                .font(.subheadline)
            }
            .padding()
            .frame(width: 400)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            
            Spacer()
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // Extracted connection logic to avoid duplication
    private func openConnection() async {
        if let existingTab = appState.workspace.tabs.first(where: { $0.connectionId == connection.id }) {
            appState.workspace.activeTabId = existingTab.id
            return
        }
        do {
            let sessionId = try await appState.sessionManager.open(connection: connection)
            let tab = SessionTab(
                connectionId: connection.id,
                sessionId: sessionId,
                title: connection.name
            )
            appState.workspace.addTab(tab)
            try appState.connectionService.markConnected(connection)
        } catch {
            appState.toastMessage = ToastMessage(
                title: "Connection Failed",
                message: error.localizedDescription,
                style: .error
            )
        }
    }
}
