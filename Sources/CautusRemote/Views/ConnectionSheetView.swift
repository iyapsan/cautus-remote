import SwiftUI
import SwiftData

/// Sheet modal for creating or editing a Connection.
///
/// UX design: Always show effective values. Source badges explain inheritance.
/// Override button activates per-field editing. Reset clears the override.
struct ConnectionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    // MARK: - Always connection-specific (no inheritance)
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

    // MARK: - RDP Overrides (the only data that interacts with inheritance)
    @State private var overrides: RDPOverrides = RDPOverrides()

    // MARK: - Computed once on appear (folder chain baseline, no connection overrides)
    @State private var inherited: RDPProfileDefaults = .global
    @State private var inheritedSourceName: String = "Global"

    @State private var isSaving: Bool = false
    @State private var hasAnyOverrides: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                // ── Header: Effective profile breadcrumb ──
                profileBreadcrumb

                // ── Section 1: Connection ──
                connectionSection

                // ── Section 2: Display ──
                displaySection

                // ── Section 3: Security ──
                securitySection

                // ── Section 4: Gateway ──
                gatewaySection

                // ── Section 5: Clipboard ──
                clipboardSection
            }
            .formStyle(.grouped)
            .navigationTitle(appState.editingConnection != nil ? "Edit Connection" : "New Connection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .automatic) {
                    if hasAnyOverrides {
                        Button("Reset Overrides") {
                            withAnimation { overrides = RDPOverrides() }
                        }
                        .foregroundStyle(.orange)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveConnection() }
                        .disabled(name.isEmpty || host.isEmpty || username.isEmpty)
                }
            }
            .frame(width: 490, height: 650)
            .onAppear { loadExistingValues() }
            .onChange(of: overrides) { _, _ in
                hasAnyOverrides = !overrides.isEmpty
            }
        }
    }

    // MARK: - Breadcrumb

    private var profileBreadcrumb: some View {
        Section {
            let breadcrumb = buildBreadcrumb()
            if !breadcrumb.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Effective Profile")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(breadcrumb)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 6, leading: 16, bottom: 4, trailing: 16))
    }

    // MARK: - Section 1: Connection

    private var connectionSection: some View {
        Section("Connection") {
            TextField("Name", text: $name)
            TextField("Host (IP or FQDN)", text: $host)
            TextField("Username", text: $username)
            SecureField("Password", text: $rawPasswordInput)

            // Port — overridable
            OverridableRow(
                "Port",
                effectiveDisplay: "\(effectivePort)",
                source: overrides.port != nil ? .connection : inheritedSource,
                isOverridden: overrides.port != nil,
                editor: {
                    TextField("", value: Binding(
                        get: { overrides.port ?? inherited.port },
                        set: { overrides.port = $0 }
                    ), format: .number)
                    .frame(width: 70)
                },
                onOverride: { overrides.port = inherited.port },
                onReset: { overrides.port = nil }
            )
        }
    }

    // MARK: - Section 2: Display

    private var displaySection: some View {
        Section("Display") {
            OverridableRow(
                "Scaling",
                effectiveDisplay: effective.scaling.displayName,
                source: overrides.scaling != nil ? .connection : inheritedSource,
                isOverridden: overrides.scaling != nil,
                editor: {
                    Picker("", selection: Binding(
                        get: { overrides.scaling ?? inherited.scaling },
                        set: { overrides.scaling = $0 }
                    )) {
                        ForEach(RDPScalingMode.allCases, id: \.self) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                },
                onOverride: { overrides.scaling = inherited.scaling },
                onReset: { overrides.scaling = nil }
            )

            OverridableRow(
                "Dynamic Resolution",
                effectiveDisplay: effective.dynamicResolution ? "Enabled" : "Disabled",
                source: overrides.dynamicResolution != nil ? .connection : inheritedSource,
                isOverridden: overrides.dynamicResolution != nil,
                editor: {
                    Toggle("", isOn: Binding(
                        get: { overrides.dynamicResolution ?? inherited.dynamicResolution },
                        set: { overrides.dynamicResolution = $0 }
                    ))
                    .labelsHidden()
                },
                onOverride: { overrides.dynamicResolution = inherited.dynamicResolution },
                onReset: { overrides.dynamicResolution = nil }
            )

            OverridableRow(
                "Color Depth",
                effectiveDisplay: effective.colorDepth.displayName,
                source: overrides.colorDepth != nil ? .connection : inheritedSource,
                isOverridden: overrides.colorDepth != nil,
                editor: {
                    Picker("", selection: Binding(
                        get: { overrides.colorDepth ?? inherited.colorDepth },
                        set: { overrides.colorDepth = $0 }
                    )) {
                        ForEach(RDPColorDepth.allCases, id: \.self) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                },
                onOverride: { overrides.colorDepth = inherited.colorDepth },
                onReset: { overrides.colorDepth = nil }
            )
        }
    }

    // MARK: - Section 3: Security

    private var securitySection: some View {
        Section("Security") {
            OverridableRow(
                "Require NLA",
                effectiveDisplay: effective.enableNLA ? "Required" : "Not required",
                source: overrides.enableNLA != nil ? .connection : inheritedSource,
                isOverridden: overrides.enableNLA != nil,
                editor: {
                    Toggle("", isOn: Binding(
                        get: { overrides.enableNLA ?? inherited.enableNLA },
                        set: { overrides.enableNLA = $0 }
                    ))
                    .labelsHidden()
                },
                onOverride: { overrides.enableNLA = inherited.enableNLA },
                onReset: { overrides.enableNLA = nil }
            )

            Group {
                Toggle("Allow Untrusted Certificates", isOn: $ignoreCertificateErrors)
                    .foregroundStyle(ignoreCertificateErrors ? .red : .primary)
                if ignoreCertificateErrors {
                    Text("⚠️ Not recommended for production environments")
                        .font(.caption)
                        .foregroundStyle(.red)
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

                OverridableRow(
                    "Gateway Mode",
                    effectiveDisplay: effective.gatewayMode.displayName,
                    source: overrides.gatewayMode != nil ? .connection : inheritedSource,
                    isOverridden: overrides.gatewayMode != nil,
                    editor: {
                        Picker("", selection: Binding(
                            get: { overrides.gatewayMode ?? inherited.gatewayMode },
                            set: { overrides.gatewayMode = $0 }
                        )) {
                            ForEach(GatewayMode.allCases, id: \.self) { m in
                                Text(m.displayName).tag(m)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    },
                    onOverride: { overrides.gatewayMode = inherited.gatewayMode },
                    onReset: { overrides.gatewayMode = nil }
                )

                OverridableRow(
                    "Bypass Local Addresses",
                    effectiveDisplay: effective.gatewayBypassLocal ? "On" : "Off",
                    source: overrides.gatewayBypassLocal != nil ? .connection : inheritedSource,
                    isOverridden: overrides.gatewayBypassLocal != nil,
                    editor: {
                        Toggle("", isOn: Binding(
                            get: { overrides.gatewayBypassLocal ?? inherited.gatewayBypassLocal },
                            set: { overrides.gatewayBypassLocal = $0 }
                        ))
                        .labelsHidden()
                    },
                    onOverride: { overrides.gatewayBypassLocal = inherited.gatewayBypassLocal },
                    onReset: { overrides.gatewayBypassLocal = nil }
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
            OverridableRow(
                "Clipboard Sync",
                effectiveDisplay: effective.enableClipboard ? "Enabled" : "Disabled",
                source: overrides.enableClipboard != nil ? .connection : inheritedSource,
                isOverridden: overrides.enableClipboard != nil,
                editor: {
                    Toggle("", isOn: Binding(
                        get: { overrides.enableClipboard ?? inherited.enableClipboard },
                        set: { overrides.enableClipboard = $0 }
                    ))
                    .labelsHidden()
                },
                onOverride: { overrides.enableClipboard = inherited.enableClipboard },
                onReset: { overrides.enableClipboard = nil }
            )
        }
    }

    // MARK: - Computed Helpers

    /// The fully resolved effective config (for display purposes only, computed cheaply from state)
    private var effective: RDPProfileDefaults {
        var r = inherited
        if let v = overrides.port                 { r.port = v }
        if let v = overrides.colorDepth           { r.colorDepth = v }
        if let v = overrides.enableClipboard      { r.enableClipboard = v }
        if let v = overrides.enableNLA            { r.enableNLA = v }
        if let v = overrides.gatewayMode          { r.gatewayMode = v }
        if let v = overrides.gatewayBypassLocal   { r.gatewayBypassLocal = v }
        if let v = overrides.reconnectMaxAttempts { r.reconnectMaxAttempts = v }
        if let v = overrides.scaling              { r.scaling = v }
        if let v = overrides.dynamicResolution    { r.dynamicResolution = v }
        return r
    }

    private var effectivePort: Int {
        overrides.port ?? inherited.port
    }

    private var inheritedSource: OverrideSource {
        appState.editingConnection?.folder.map { .folder(name: $0.name) } ?? .global
    }

    private func buildBreadcrumb() -> String {
        guard let conn = appState.editingConnection else { return "" }
        var parts: [String] = ["Global"]
        var chain: [String] = []
        var f = conn.folder
        while let folder = f {
            chain.append(folder.name)
            f = folder.parentFolder
        }
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
            overrides = editing.rdpOverrides
            hasAnyOverrides = !overrides.isEmpty

            // Compute inherited baseline: resolve folder chain WITHOUT this connection's overrides.
            // We manually walk the chain here (same logic as resolveRDPConfig but with empty overrides).
            let chain = buildFolderChain(from: editing.folder)
            inherited = chain.reduce(RDPProfileDefaults.global) { acc, f in
                f.rdpDefaults ?? acc
            }.validated()
            inheritedSourceName = editing.folder?.name ?? "Global"
        }
    }

    private func saveConnection() {
        isSaving = true
        let finalPort = overrides.port ?? inherited.port

        let target: Connection
        if let editing = appState.editingConnection {
            editing.name = name
            editing.host = host
            editing.port = finalPort
            editing.username = username
            editing.gatewayUrl = useGateway ? (gatewayUrl.isEmpty ? nil : gatewayUrl) : nil
            editing.gatewayUsername = (!useSameCredentials && useGateway) ? (gatewayUsername.isEmpty ? nil : gatewayUsername) : nil
            editing.ignoreCertificateErrors = ignoreCertificateErrors
            editing.rdpOverrides = overrides.isEmpty ? RDPOverrides() : overrides
            target = editing
        } else {
            let c = Connection(
                name: name,
                host: host,
                port: finalPort,
                username: username,
                gatewayUrl: useGateway ? (gatewayUrl.isEmpty ? nil : gatewayUrl) : nil,
                gatewayUsername: (!useSameCredentials && useGateway) ? (gatewayUsername.isEmpty ? nil : gatewayUsername) : nil,
                ignoreCertificateErrors: ignoreCertificateErrors
            )
            c.rdpOverrides = overrides
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

