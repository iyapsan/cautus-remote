import SwiftUI
import SwiftData

/// Sheet modal for creating or editing a Connection.
struct ConnectionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    // Basic Fields
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "3389"
    @State private var username: String = ""
    @State private var rawPasswordInput: String = ""

    // Gateway Fields
    @State private var useGateway: Bool = false
    @State private var gatewayUrl: String = ""
    @State private var gatewayUsername: String = ""
    @State private var ignoreCertificateErrors: Bool = false

    // RDP Overrides — nil means "inherit from folder chain"
    @State private var overrides: RDPOverrides = RDPOverrides()

    // State
    @State private var isAdvancedExpanded: Bool = false
    @State private var isOverridesExpanded: Bool = false
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Connection Name", text: $name)
                    TextField("Host (IP or FQDN)", text: $host)
                    TextField("Port", text: $port)
                        .disabled(overrides.port != nil) // Port can be overridden below
                    TextField("Username", text: $username)
                    SecureField("Password", text: $rawPasswordInput)
                }

                Section {
                    DisclosureGroup("Advanced Settings", isExpanded: $isAdvancedExpanded) {
                        Toggle("Use RD Gateway", isOn: $useGateway)

                        if useGateway {
                            TextField("Gateway URL", text: $gatewayUrl)
                            TextField("Gateway Username", text: $gatewayUsername)
                        }

                        Toggle("Ignore Certificate Errors (Insecure)", isOn: $ignoreCertificateErrors)
                    }
                }

                // MARK: - Overrides Section
                Section {
                    DisclosureGroup("Profile Overrides", isExpanded: $isOverridesExpanded) {

                        // Port override
                        HStack {
                            Text("Port")
                            Spacer()
                            Toggle("Override", isOn: Binding(
                                get: { overrides.port != nil },
                                set: { on in overrides.port = on ? (Int(port) ?? 3389) : nil }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            if overrides.port != nil {
                                TextField("", value: Binding($overrides.port)!, format: .number)
                                    .frame(width: 65)
                                    .multilineTextAlignment(.trailing)
                            }
                        }

                        // Color depth override
                        HStack {
                            Text("Color Depth")
                            Spacer()
                            Toggle("Override", isOn: Binding(
                                get: { overrides.colorDepth != nil },
                                set: { on in overrides.colorDepth = on ? .bpp32 : nil }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            if let _ = overrides.colorDepth {
                                Picker("", selection: Binding($overrides.colorDepth)!) {
                                    ForEach(RDPColorDepth.allCases, id: \.self) { depth in
                                        Text(depth.displayName).tag(depth)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 160)
                            }
                        }

                        // Bool tri-state overrides: Inherit | On | Off
                        BoolOverrideRow("Clipboard", binding: $overrides.enableClipboard)
                        BoolOverrideRow("NLA Authentication", binding: $overrides.enableNLA)
                        BoolOverrideRow("Dynamic Resolution", binding: $overrides.dynamicResolution)

                        // Scaling override
                        HStack {
                            Text("Scaling")
                            Spacer()
                            Toggle("Override", isOn: Binding(
                                get: { overrides.scaling != nil },
                                set: { on in overrides.scaling = on ? .fit : nil }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            if let _ = overrides.scaling {
                                Picker("", selection: Binding($overrides.scaling)!) {
                                    ForEach(RDPScalingMode.allCases, id: \.self) { mode in
                                        Text(mode.displayName).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 120)
                            }
                        }

                        // Reconnect override
                        HStack {
                            Text("Max Reconnect Attempts")
                            Spacer()
                            Toggle("Override", isOn: Binding(
                                get: { overrides.reconnectMaxAttempts != nil },
                                set: { on in overrides.reconnectMaxAttempts = on ? 5 : nil }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            if overrides.reconnectMaxAttempts != nil {
                                Stepper("\(overrides.reconnectMaxAttempts!)",
                                        value: Binding($overrides.reconnectMaxAttempts)!,
                                        in: 0...20)
                            }
                        }
                    }
                } footer: {
                    Text("Fields set to \"Inherit\" use the parent folder's defaults (or global defaults).")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(appState.editingConnection != nil ? "Edit Connection" : "New Connection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveConnection() }
                        .disabled(name.isEmpty || host.isEmpty || username.isEmpty)
                }
            }
            .frame(width: 480, height: 560)
            .onAppear { loadExistingValues() }
        }
    }

    // MARK: - Private Helpers

    private func loadExistingValues() {
        if let editing = appState.editingConnection {
            name = editing.name
            host = editing.host
            port = String(editing.port)
            username = editing.username
            gatewayUrl = editing.gatewayUrl ?? ""
            gatewayUsername = editing.gatewayUsername ?? ""
            useGateway = !gatewayUrl.isEmpty
            ignoreCertificateErrors = editing.ignoreCertificateErrors
            overrides = editing.rdpOverrides
        }
    }

    private func saveConnection() {
        isSaving = true
        let finalPort = Int(port) ?? 3389

        let targetConnection: Connection
        if let editing = appState.editingConnection {
            editing.name = name
            editing.host = host
            editing.port = finalPort
            editing.username = username
            editing.gatewayUrl = useGateway ? (gatewayUrl.isEmpty ? nil : gatewayUrl) : nil
            editing.gatewayUsername = useGateway ? (gatewayUsername.isEmpty ? nil : gatewayUsername) : nil
            editing.ignoreCertificateErrors = ignoreCertificateErrors
            editing.rdpOverrides = overrides
            targetConnection = editing
        } else {
            let newConnection = Connection(
                name: name,
                host: host,
                port: finalPort,
                username: username,
                gatewayUrl: useGateway ? (gatewayUrl.isEmpty ? nil : gatewayUrl) : nil,
                gatewayUsername: useGateway ? (gatewayUsername.isEmpty ? nil : gatewayUsername) : nil,
                ignoreCertificateErrors: ignoreCertificateErrors
            )
            newConnection.rdpOverrides = overrides
            modelContext.insert(newConnection)
            targetConnection = newConnection
        }

        if !rawPasswordInput.isEmpty {
            do {
                try appState.keychainService.storePassword(rawPasswordInput, for: targetConnection.id)
            } catch {
                print("Failed to save password: \(error)")
            }
        }

        try? modelContext.save()
        appState.isShowingConnectionSheet = false
        dismiss()
    }
}

// MARK: - BoolOverrideRow

/// Tri-state segmented control: Inherit | On | Off for a Bool? override field.
private struct BoolOverrideRow: View {
    let label: String
    @Binding var binding: Bool?

    init(_ label: String, binding: Binding<Bool?>) {
        self.label = label
        self._binding = binding
    }

    private enum TriState: Int, CaseIterable {
        case inherit = 0, on = 1, off = 2
        var displayName: String {
            switch self { case .inherit: return "Inherit"; case .on: return "On"; case .off: return "Off" }
        }
    }

    private var triState: TriState {
        switch binding {
        case .none: return .inherit
        case .some(true): return .on
        case .some(false): return .off
        }
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Picker(label, selection: Binding(
                get: { triState },
                set: { newState in
                    switch newState {
                    case .inherit: binding = nil
                    case .on:      binding = true
                    case .off:     binding = false
                    }
                }
            )) {
                ForEach(TriState.allCases, id: \.self) { state in
                    Text(state.displayName).tag(state)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .labelsHidden()
        }
    }
}
