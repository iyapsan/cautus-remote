import SwiftUI
import SwiftData

/// Sheet modal for creating or editing a Connection.
///
/// UX: Always shows effective (resolved) values. Source badges explain inheritance.
/// Override button activates per-field editing. Reset clears the override.
/// State is typed against `RDPPatch` — only non-nil fields are persisted.
struct ConnectionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    // Always connection-specific (no inheritance)
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var username: String = ""
    @State private var rawPasswordInput: String = ""
    @State private var ignoreCertificateErrors: Bool = false

    // Gateway (connection-specific identity, not inherited in v1)
    @State private var useGateway: Bool = false
    @State private var gatewayUrl: String = ""
    @State private var gatewayUsername: String = ""
    @State private var useSameCredentials: Bool = false

    // RDP Patch — only non-nil fields are persisted; nil = inherit
    @State private var patch: RDPPatch = RDPPatch()

    // Baseline: what the folder chain resolves to without this connection's patch
    @State private var inherited: RDPResolvedConfig = .global
    @State private var hasAnyOverrides: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                let crumb = buildBreadcrumb()
                if !crumb.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Effective Profile")
                                .font(.caption2).fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase).tracking(0.5)
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(crumb).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 6, leading: 16, bottom: 4, trailing: 16))
                }
                
                if hasAnyOverrides { activeOverridesSummary }
                connectionSection
                displaySection
                securitySection
                gatewaySection
                clipboardSection
                redirectionSection
                connectionBehaviorSection
            }
            .formStyle(.grouped)
            .navigationTitle(appState.editingConnection != nil ? "Edit Connection" : "New Connection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .automatic) {
                    if hasAnyOverrides {
                        Button("Reset All Overrides") { withAnimation { patch = RDPPatch() } }
                            .foregroundStyle(.orange)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveConnection() }
                        .disabled(name.isEmpty || host.isEmpty || username.isEmpty)
                }
            }
            .frame(width: 490, height: 660)
            .onAppear { loadExistingValues() }
            .onChange(of: patch) { _, _ in hasAnyOverrides = !patch.isEmpty }
        }
    }

    // MARK: - Overrides Summary

    private var activeOverridesSummary: some View {
        Section {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(Color.orange).frame(width: 8, height: 8).padding(.top, 4)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Overrides Active (\(activeFieldNames.count))")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.orange)
                    Text(activeFieldNames.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .listRowBackground(Color.orange.opacity(0.06))
    }

    private var activeFieldNames: [String] {
        var n: [String] = []
        if patch.port != nil               { n.append("Port") }
        if patch.colorDepth != nil         { n.append("Color Depth") }
        if patch.clipboardEnabled != nil   { n.append("Clipboard Sharing") }
        if patch.nlaRequired != nil        { n.append("NLA") }
        if patch.gatewayMode != nil        { n.append("Gateway Mode") }
        if patch.gatewayBypassLocal != nil { n.append("Bypass Local") }
        if patch.reconnectAttempts != nil  { n.append("Reconnect Attempts") }
        if patch.scaling != nil            { n.append("Scaling") }
        if patch.dynamicResolution != nil  { n.append("Auto Resize Display") }
        if patch.audioEnabled != nil       { n.append("Audio") }
        if patch.driveRedirectionEnabled != nil { n.append("Drive Redirection") }
        return n
    }

    // MARK: - Section 1: Connection

    private var connectionSection: some View {
        Section("Connection") {
            TextField("Name", text: $name)
            TextField("Host (IP or FQDN)", text: $host)
            TextField("Username", text: $username)
            SecureField("Password", text: $rawPasswordInput)

            // Port — String binding avoids comma formatting (3389, not 3,389)
            OverridableRow("Port",
                source: patch.port != nil ? .connection : inheritedSource,
                isOverridden: patch.port != nil,
                editor: {
                    TextField("", text: Binding(
                        get: { "\(patch.port ?? inherited.port)" },
                        set: { patch.port = Int($0) }
                    )).frame(width: 70)
                },
                onOverride: { patch.port = inherited.port },
                onReset: { patch.port = nil }
            )
        }
    }

    // MARK: - Section 2: Display

    private var displaySection: some View {
        Section("Display") {
            OverridableRow("Scaling",
                source: patch.scaling != nil ? .connection : inheritedSource,
                isOverridden: patch.scaling != nil,
                editor: {
                    Picker("", selection: Binding(
                        get: { patch.scaling ?? inherited.scaling },
                        set: { patch.scaling = $0 }
                    )) {
                        ForEach(RDPScalingMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(width: 140)
                },
                onOverride: { patch.scaling = inherited.scaling },
                onReset: { patch.scaling = nil }
            )

            OverridableRow("Auto Resize Display",
                source: patch.dynamicResolution != nil ? .connection : inheritedSource,
                isOverridden: patch.dynamicResolution != nil,
                editor: {
                    Toggle("", isOn: Binding(
                        get: { patch.dynamicResolution ?? inherited.dynamicResolution },
                        set: { patch.dynamicResolution = $0 }
                    )).labelsHidden()
                },
                onOverride: { patch.dynamicResolution = inherited.dynamicResolution },
                onReset: { patch.dynamicResolution = nil }
            )

            OverridableRow("Color Depth",
                source: patch.colorDepth != nil ? .connection : inheritedSource,
                isOverridden: patch.colorDepth != nil,
                editor: {
                    Picker("", selection: Binding(
                        get: { patch.colorDepth ?? inherited.colorDepth },
                        set: { patch.colorDepth = $0 }
                    )) {
                        ForEach(RDPColorDepth.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(width: 190)
                },
                onOverride: { patch.colorDepth = inherited.colorDepth },
                onReset: { patch.colorDepth = nil }
            )
        }
    }

    // MARK: - Section 3: Security

    private var securitySection: some View {
        Section("Security") {
            OverridableRow("Require NLA",
                source: patch.nlaRequired != nil ? .connection : inheritedSource,
                isOverridden: patch.nlaRequired != nil,
                editor: {
                    Toggle("", isOn: Binding(
                        get: { patch.nlaRequired ?? inherited.nlaRequired },
                        set: { patch.nlaRequired = $0 }
                    )).labelsHidden()
                },
                onOverride: { patch.nlaRequired = inherited.nlaRequired },
                onReset: { patch.nlaRequired = nil }
            )

            Group {
                Toggle("Allow Self-Signed Certificates", isOn: $ignoreCertificateErrors)
                    .foregroundStyle(ignoreCertificateErrors ? .red : .primary)
                if ignoreCertificateErrors {
                    Text("⚠️ Not recommended for production environments")
                        .font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Section 4: Gateway

    private var gatewaySection: some View {
        Section("Gateway") {
            Toggle("Use RD Gateway", isOn: $useGateway.animation())
            if useGateway {
                TextField("Gateway Host", text: $gatewayUrl)

                OverridableRow("Gateway Mode",
                    source: patch.gatewayMode != nil ? .connection : inheritedSource,
                    isOverridden: patch.gatewayMode != nil,
                    editor: {
                        Picker("", selection: Binding(
                            get: { patch.gatewayMode ?? inherited.gatewayMode },
                            set: { patch.gatewayMode = $0 }
                        )) {
                            ForEach(GatewayMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }.labelsHidden().frame(width: 100)
                    },
                    onOverride: { patch.gatewayMode = inherited.gatewayMode },
                    onReset: { patch.gatewayMode = nil }
                )

                OverridableRow("Bypass Local Addresses",
                    source: patch.gatewayBypassLocal != nil ? .connection : inheritedSource,
                    isOverridden: patch.gatewayBypassLocal != nil,
                    editor: {
                        Toggle("", isOn: Binding(
                            get: { patch.gatewayBypassLocal ?? inherited.gatewayBypassLocal },
                            set: { patch.gatewayBypassLocal = $0 }
                        )).labelsHidden()
                    },
                    onOverride: { patch.gatewayBypassLocal = inherited.gatewayBypassLocal },
                    onReset: { patch.gatewayBypassLocal = nil }
                )

                Toggle("Use same credentials as target", isOn: $useSameCredentials.animation())
                if !useSameCredentials {
                    TextField("Gateway Username", text: $gatewayUsername)
                }
            }
        }
    }

    // MARK: - Section 5: Clipboard
    
    private var clipboardSection: some View {
        Section("Clipboard") {
            OverridableRow("Clipboard Sharing",
                source: patch.clipboardEnabled != nil ? .connection : inheritedSource,
                isOverridden: patch.clipboardEnabled != nil,
                editor: {
                    Toggle("", isOn: Binding(
                        get: { patch.clipboardEnabled ?? inherited.clipboardEnabled },
                        set: { patch.clipboardEnabled = $0 }
                    )).labelsHidden()
                },
                onOverride: { patch.clipboardEnabled = inherited.clipboardEnabled },
                onReset: { patch.clipboardEnabled = nil }
            )
        }
    }

    // MARK: - Section 5b: Redirection
    
    private var redirectionSection: some View {
        Section("Redirection") {
            OverridableRow("Audio",
                source: patch.audioEnabled != nil ? .connection : inheritedSource,
                isOverridden: patch.audioEnabled != nil,
                editor: {
                    Toggle("", isOn: Binding(
                        get: { patch.audioEnabled ?? inherited.audioEnabled },
                        set: { patch.audioEnabled = $0 }
                    )).labelsHidden()
                },
                onOverride: { patch.audioEnabled = inherited.audioEnabled },
                onReset: { patch.audioEnabled = nil }
            )
            
            OverridableRow("Drive Redirection",
                source: patch.driveRedirectionEnabled != nil ? .connection : inheritedSource,
                isOverridden: patch.driveRedirectionEnabled != nil,
                editor: {
                    Toggle("", isOn: Binding(
                        get: { patch.driveRedirectionEnabled ?? inherited.driveRedirectionEnabled },
                        set: { patch.driveRedirectionEnabled = $0 }
                    )).labelsHidden()
                },
                onOverride: { patch.driveRedirectionEnabled = inherited.driveRedirectionEnabled },
                onReset: { patch.driveRedirectionEnabled = nil }
            )
        }
    }

    // MARK: - Section 6: Connection Behavior

    private var connectionBehaviorSection: some View {
        Section("Connection Behavior") {
            OverridableRow("Reconnect Attempts",
                source: patch.reconnectAttempts != nil ? .connection : inheritedSource,
                isOverridden: patch.reconnectAttempts != nil,
                editor: {
                    Stepper("\(patch.reconnectAttempts ?? inherited.reconnectAttempts)",
                        value: Binding(
                            get: { patch.reconnectAttempts ?? inherited.reconnectAttempts },
                            set: { patch.reconnectAttempts = $0 }
                        ),
                        in: 0...20
                    )
                },
                onOverride: { patch.reconnectAttempts = inherited.reconnectAttempts },
                onReset: { patch.reconnectAttempts = nil }
            )
        }
    }

    // MARK: - Computed Helpers

    /// Live effective config for display — cheap in-memory merge from local state, not a disk decode.
    private var effective: RDPResolvedConfig { inherited.applying(patch) }

    private var inheritedSource: OverrideSource {
        appState.editingConnection?.folder.map { .folder(name: $0.name) } ?? .global
    }

    private func buildBreadcrumb() -> String {
        guard let conn = appState.editingConnection else { return "" }
        var parts: [String] = ["Global"]
        var chain: [String] = []
        var f = conn.folder
        while let folder = f { chain.append(folder.name); f = folder.parentFolder }
        parts += chain.reversed()
        parts.append(conn.name)
        return parts.joined(separator: " → ")
    }

    // MARK: - Load / Save

    private func loadExistingValues() {
        if let editing = appState.editingConnection {
            name = editing.name
            host = editing.host
            username = editing.username
            gatewayUrl = editing.gatewayUrl ?? ""
            gatewayUsername = editing.gatewayUsername ?? ""
            useGateway = !gatewayUrl.isEmpty
            ignoreCertificateErrors = editing.ignoreCertificateErrors
            patch = editing.rdpPatch ?? RDPPatch()
            hasAnyOverrides = !patch.isEmpty

            // Compute inherited baseline: folder chain WITHOUT this connection's patch.
            // Uses the canonical buildFolderChain(for:) — no local duplicate.
            let chain = buildFolderChain(for: editing.folder)
            inherited = chain.reduce(RDPResolvedConfig.global) { acc, f in
                f.rdpPatch.map { acc.applying($0) } ?? acc
            }.validated()
        }
    }

    private func saveConnection() {
        let finalPort = patch.port ?? inherited.port

        let target: Connection
        if let editing = appState.editingConnection {
            editing.name = name
            editing.host = host
            editing.port = finalPort
            editing.username = username
            editing.gatewayUrl = useGateway ? (gatewayUrl.isEmpty ? nil : gatewayUrl) : nil
            editing.gatewayUsername = (!useSameCredentials && useGateway) ? (gatewayUsername.isEmpty ? nil : gatewayUsername) : nil
            editing.ignoreCertificateErrors = ignoreCertificateErrors
            editing.rdpPatch = patch.isEmpty ? nil : patch  // nil = no overrides at all
            target = editing
        } else {
            let c = Connection(
                name: name, host: host, port: finalPort, username: username,
                gatewayUrl: useGateway ? (gatewayUrl.isEmpty ? nil : gatewayUrl) : nil,
                gatewayUsername: (!useSameCredentials && useGateway) ? (gatewayUsername.isEmpty ? nil : gatewayUsername) : nil,
                ignoreCertificateErrors: ignoreCertificateErrors
            )
            c.rdpPatch = patch.isEmpty ? nil : patch
            modelContext.insert(c)
            target = c
        }

        if !rawPasswordInput.isEmpty {
            try? appState.keychainService.storePassword(rawPasswordInput, for: target.id)
        }
        try? modelContext.save()
        appState.isShowingConnectionSheet = false
        dismiss()
    }
}
