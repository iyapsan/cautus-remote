import SwiftUI
import SwiftData

/// Inspector view for Connection properties and overrides.
///
/// Modifies the associated `Connection` in place.
struct ConnectionInspectorView: View {
    let connection: Connection
    
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    // Extracted connection fields (editable)
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var username: String = ""
    @State private var rawPasswordInput: String = ""
    @State private var ignoreCertificateErrors: Bool = false
    
    // Gateway fields
    @State private var useGateway: Bool = false
    @State private var gatewayUrl: String = ""
    @State private var gatewayUsername: String = ""
    @State private var useSameCredentials: Bool = false
    
    // Override patch
    @State private var patch: RDPPatch = RDPPatch()
    @State private var inherited: RDPResolvedConfig = .global
    
    // Collapsible section states
    @AppStorage("inspector.connection.expanded.connection") private var isConnectionExpanded = true
    @AppStorage("inspector.connection.expanded.display") private var isDisplayExpanded = true
    @AppStorage("inspector.connection.expanded.security") private var isSecurityExpanded = true
    @AppStorage("inspector.connection.expanded.gateway") private var isGatewayExpanded = false
    @AppStorage("inspector.connection.expanded.clipboard") private var isClipboardExpanded = false
    @AppStorage("inspector.connection.expanded.redirection") private var isRedirectionExpanded = false
    @AppStorage("inspector.connection.expanded.behavior") private var isBehaviorExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            InspectorHeaderView(
                title: connection.name,
                subtitle: connection.host.isEmpty ? "No host configured" : connection.host,
                icon: "desktopcomputer",
                protocolBadge: "RDP"
            )
            
            let crumbItems = buildBreadcrumb()
            if !crumbItems.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(crumbItems.enumerated()), id: \.offset) { index, item in
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(index == crumbItems.count - 1 ? .primary : .secondary)
                        
                        if index < crumbItems.count - 1 {
                            Text("›")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                #if os(macOS)
                .background(Color(NSColor.windowBackgroundColor))
                #else
                .background(Color(UIColor.windowBackground))
                #endif
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        // ── Connection ──────────────────────────────────────────────────
                        CollapsibleSectionCard("Connection", isExpanded: $isConnectionExpanded, isFirstSection: true) {
                            Group {
                                TextField("Name", text: $name)
                                    .onSubmit { saveConnection() }
                                
                                TextField("Host (IP or FQDN)", text: $host)
                                    .onSubmit { saveConnection() }
                                
                                TextField("Username", text: $username)
                                    .onSubmit { saveConnection() }
                                
                                SecureField("Password", text: $rawPasswordInput)
                                    .onSubmit { saveConnection() }
                            }
                            .padding(.leading, 7)
                            
                            OverridableRow("Port",
                                source: patch.port != nil ? .connection : inheritedSource,
                                isOverridden: patch.port != nil,
                                editor: {
                                    TextField("", text: Binding(
                                        get: { "\(patch.port ?? inherited.port)" },
                                        set: { if let p = Int($0) { patch.port = p } }
                                    ))
                                    .frame(width: 70)
                                    .onSubmit { saveConnection() }
                                },
                                onOverride: { patch.port = inherited.port; saveConnection() },
                                onReset: { patch.port = nil; saveConnection() }
                            )
                        }
                        .id("Port")
                        
                        // ── Display ─────────────────────────────────────────────────────
                        CollapsibleSectionCard("Display", isExpanded: $isDisplayExpanded) {
                            OverridableRow("Scaling",
                                source: patch.scaling != nil ? .connection : inheritedSource,
                                isOverridden: patch.scaling != nil,
                                editor: {
                                    Picker("", selection: Binding(
                                        get: { patch.scaling ?? inherited.scaling },
                                        set: { patch.scaling = $0; saveConnection() }
                                    )) {
                                        ForEach(RDPScalingMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                                    }.labelsHidden().frame(width: 140)
                                },
                                onOverride: { patch.scaling = inherited.scaling; saveConnection() },
                                onReset: { patch.scaling = nil; saveConnection() }
                            )
                            .id("Scaling")
                            
                            OverridableRow("Auto Resize Display",
                                source: patch.dynamicResolution != nil ? .connection : inheritedSource,
                                isOverridden: patch.dynamicResolution != nil,
                                editor: {
                                    Toggle("", isOn: Binding(
                                        get: { patch.dynamicResolution ?? inherited.dynamicResolution },
                                        set: { patch.dynamicResolution = $0; saveConnection() }
                                    )).labelsHidden()
                                },
                                onOverride: { patch.dynamicResolution = inherited.dynamicResolution; saveConnection() },
                                onReset: { patch.dynamicResolution = nil; saveConnection() }
                            )
                            .id("Auto Resize Display")
                            
                            OverridableRow("Color Depth",
                                source: patch.colorDepth != nil ? .connection : inheritedSource,
                                isOverridden: patch.colorDepth != nil,
                                editor: {
                                    Picker("", selection: Binding(
                                        get: { patch.colorDepth ?? inherited.colorDepth },
                                        set: { patch.colorDepth = $0; saveConnection() }
                                    )) {
                                        ForEach(RDPColorDepth.allCases, id: \.self) { Text($0.displayName).tag($0) }
                                    }.labelsHidden().frame(width: 190)
                                },
                                onOverride: { patch.colorDepth = inherited.colorDepth; saveConnection() },
                                onReset: { patch.colorDepth = nil; saveConnection() }
                            )
                            .id("Color Depth")
                        }
                        
                        // ── Security ────────────────────────────────────────────────────
                        CollapsibleSectionCard("Security", isExpanded: $isSecurityExpanded) {
                            OverridableRow("Require NLA",
                                source: patch.nlaRequired != nil ? .connection : inheritedSource,
                                isOverridden: patch.nlaRequired != nil,
                                editor: {
                                    Toggle("", isOn: Binding(
                                        get: { patch.nlaRequired ?? inherited.nlaRequired },
                                        set: { patch.nlaRequired = $0; saveConnection() }
                                    )).labelsHidden()
                                },
                                onOverride: { patch.nlaRequired = inherited.nlaRequired; saveConnection() },
                                onReset: { patch.nlaRequired = nil; saveConnection() }
                            )
                            .id("NLA")
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Allow Self-Signed Certificates", isOn: Binding(
                                    get: { ignoreCertificateErrors },
                                    set: { ignoreCertificateErrors = $0; saveConnection() }
                                ))
                                
                                if ignoreCertificateErrors {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                        Text("Not recommended for production")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                }
                            }
                            .padding(.leading, 7)
                        }
                        
                        // ── Gateway ─────────────────────────────────────────────────────
                        CollapsibleSectionCard("Gateway", isExpanded: $isGatewayExpanded, accessory: {
                            Text(useGateway ? "Enabled" : "Disabled")
                        }) {
                            Toggle("Use RD Gateway", isOn: Binding(
                                get: { useGateway },
                                set: { useGateway = $0; saveConnection() }
                            ).animation())
                            .padding(.leading, 7)
                            
                            if useGateway {
                                TextField("Gateway Host", text: $gatewayUrl)
                                    .onSubmit { saveConnection() }
                                    .padding(.leading, 7)
                                
                                OverridableRow("Gateway Mode",
                                    source: patch.gatewayMode != nil ? .connection : inheritedSource,
                                    isOverridden: patch.gatewayMode != nil,
                                    editor: {
                                        Picker("", selection: Binding(
                                            get: { patch.gatewayMode ?? inherited.gatewayMode },
                                            set: { patch.gatewayMode = $0; saveConnection() }
                                        )) {
                                            ForEach(GatewayMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                                        }.labelsHidden().frame(width: 100)
                                    },
                                    onOverride: { patch.gatewayMode = inherited.gatewayMode; saveConnection() },
                                    onReset: { patch.gatewayMode = nil; saveConnection() }
                                )
                                .id("Gateway Mode")
                                
                                OverridableRow("Bypass Local Addresses",
                                    source: patch.gatewayBypassLocal != nil ? .connection : inheritedSource,
                                    isOverridden: patch.gatewayBypassLocal != nil,
                                    editor: {
                                        Toggle("", isOn: Binding(
                                            get: { patch.gatewayBypassLocal ?? inherited.gatewayBypassLocal },
                                            set: { patch.gatewayBypassLocal = $0; saveConnection() }
                                        )).labelsHidden()
                                    },
                                    onOverride: { patch.gatewayBypassLocal = inherited.gatewayBypassLocal; saveConnection() },
                                    onReset: { patch.gatewayBypassLocal = nil; saveConnection() }
                                )
                                .id("Bypass Local")
                                
                                Toggle("Use same credentials as target", isOn: Binding(
                                    get: { useSameCredentials },
                                    set: { useSameCredentials = $0; saveConnection() }
                                ).animation())
                                .padding(.leading, 7)
                                
                                if !useSameCredentials {
                                    TextField("Gateway Username", text: $gatewayUsername)
                                        .onSubmit { saveConnection() }
                                        .padding(.leading, 7)
                                }
                            }
                        }
                        
                        // ── Clipboard ───────────────────────────────────────────────────
                        CollapsibleSectionCard("Clipboard", isExpanded: $isClipboardExpanded, accessory: {
                            Text(effective.clipboardEnabled ? "Enabled" : "Disabled")
                        }) {
                            OverridableRow("Clipboard Sharing",
                                source: patch.clipboardEnabled != nil ? .connection : inheritedSource,
                                isOverridden: patch.clipboardEnabled != nil,
                                editor: {
                                    Toggle("", isOn: Binding(
                                        get: { patch.clipboardEnabled ?? inherited.clipboardEnabled },
                                        set: { patch.clipboardEnabled = $0; saveConnection() }
                                    )).labelsHidden()
                                },
                                onOverride: { patch.clipboardEnabled = inherited.clipboardEnabled; saveConnection() },
                                onReset: { patch.clipboardEnabled = nil; saveConnection() }
                            )
                            .id("Clipboard Sharing")
                        }
                        
                        // ── Redirection ─────────────────────────────────────────────────
                        CollapsibleSectionCard("Redirection", isExpanded: $isRedirectionExpanded) {
                            OverridableRow("Audio",
                                source: patch.audioEnabled != nil ? .connection : inheritedSource,
                                isOverridden: patch.audioEnabled != nil,
                                editor: {
                                    Toggle("", isOn: Binding(
                                        get: { patch.audioEnabled ?? inherited.audioEnabled },
                                        set: { patch.audioEnabled = $0; saveConnection() }
                                    )).labelsHidden()
                                },
                                onOverride: { patch.audioEnabled = inherited.audioEnabled; saveConnection() },
                                onReset: { patch.audioEnabled = nil; saveConnection() }
                            )
                            .id("Audio")
                            
                            OverridableRow("Drive Redirection",
                                source: patch.driveRedirectionEnabled != nil ? .connection : inheritedSource,
                                isOverridden: patch.driveRedirectionEnabled != nil,
                                editor: {
                                    Toggle("", isOn: Binding(
                                        get: { patch.driveRedirectionEnabled ?? inherited.driveRedirectionEnabled },
                                        set: { patch.driveRedirectionEnabled = $0; saveConnection() }
                                    )).labelsHidden()
                                },
                                onOverride: { patch.driveRedirectionEnabled = inherited.driveRedirectionEnabled; saveConnection() },
                                onReset: { patch.driveRedirectionEnabled = nil; saveConnection() }
                            )
                            .id("Drive Redirection")
                        }
                        
                        // ── Connection Behavior ─────────────────────────────────────────
                        CollapsibleSectionCard("Connection Behavior", isExpanded: $isBehaviorExpanded) {
                            OverridableRow("Reconnect Attempts",
                                source: patch.reconnectAttempts != nil ? .connection : inheritedSource,
                                isOverridden: patch.reconnectAttempts != nil,
                                editor: {
                                    Stepper("\(patch.reconnectAttempts ?? inherited.reconnectAttempts)",
                                        value: Binding(
                                            get: { patch.reconnectAttempts ?? inherited.reconnectAttempts },
                                            set: { patch.reconnectAttempts = $0; saveConnection() }
                                        ),
                                        in: 0...20
                                    )
                                },
                                onOverride: { patch.reconnectAttempts = inherited.reconnectAttempts; saveConnection() },
                                onReset: { patch.reconnectAttempts = nil; saveConnection() }
                            )
                            .id("Reconnect Attempts")
                        }
                        
                        // ── Reset ───────────────────────────────────────────────────────
                        if !patch.isEmpty {
                            Button {
                                withAnimation {
                                    patch = RDPPatch()
                                    saveConnection()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.uturn.backward.circle")
                                    Text("Restore Inherited Settings")
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                        }
                        

                        
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity)
                }
            }
            
            // ── Connect Action (Sticky Bottom) ──────────────────────────────
            VStack(spacing: 0) {
                Divider()
                Button {
                    Task { await openConnection() } // Handled asynchronously natively in view
                } label: {
                    Text("Connect")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .onAppear { loadExistingValues() }
        .onChange(of: connection.id) { _, _ in loadExistingValues() }
    }
    
    // MARK: - Computed Helpers

    private var effective: RDPResolvedConfig { inherited.applying(patch) }
    
    private var inheritedSource: OverrideSource {
        connection.folder.map { .folder(name: $0.name) } ?? .global
    }
    
    private func buildBreadcrumb() -> [String] {
        var parts: [String] = ["Global"]
        var chain: [String] = []
        var f = connection.folder
        while let folder = f { chain.append(folder.name); f = folder.parentFolder }
        parts += chain.reversed()
        parts.append(connection.name)
        return parts
    }
    
    // MARK: - Load / Save
    
    private func loadExistingValues() {
        name = connection.name
        host = connection.host
        username = connection.username
        gatewayUrl = connection.gatewayUrl ?? ""
        gatewayUsername = connection.gatewayUsername ?? ""
        useGateway = !gatewayUrl.isEmpty
        useSameCredentials = useGateway && gatewayUsername.isEmpty
        ignoreCertificateErrors = connection.ignoreCertificateErrors
        patch = connection.rdpPatch ?? RDPPatch()
        
        // Keychain lookup omitted for simplicity; usually injected via appState/service
        
        let chain = buildFolderChain(for: connection.folder)
        inherited = chain.reduce(RDPResolvedConfig.global) { acc, f in
            f.rdpPatch.map { acc.applying($0) } ?? acc
        }.validated()
    }
    
    private func saveConnection() {
        let finalPort = patch.port ?? inherited.port
        
        connection.name = name
        connection.host = host
        connection.port = finalPort
        connection.username = username
        connection.gatewayUrl = useGateway ? (gatewayUrl.isEmpty ? nil : gatewayUrl) : nil
        connection.gatewayUsername = (!useSameCredentials && useGateway) ? (gatewayUsername.isEmpty ? nil : gatewayUsername) : nil
        connection.ignoreCertificateErrors = ignoreCertificateErrors
        connection.rdpPatch = patch.isEmpty ? nil : patch
        
        if !rawPasswordInput.isEmpty {
            try? appState.keychainService.storePassword(rawPasswordInput, for: connection.id)
            rawPasswordInput = ""
        }
        
        try? modelContext.save()
    }
    
    private func duplicateConnection() {
        let copy = Connection(
            name: "\(connection.name) copy",
            host: connection.host,
            port: connection.port,
            username: connection.username,
            gatewayUrl: connection.gatewayUrl,
            gatewayUsername: connection.gatewayUsername,
            ignoreCertificateErrors: connection.ignoreCertificateErrors
        )
        copy.folder = connection.folder
        if let origPatch = connection.rdpPatch {
            copy.rdpPatch = origPatch // RDPPatch is a struct, natural copy by value
        }
        modelContext.insert(copy)
        try? modelContext.save()
        appState.toastMessage = ToastMessage(title: "Connection Duplicated", message: copy.name, style: .success)
    }
    
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
