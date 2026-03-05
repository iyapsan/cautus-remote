import SwiftUI
import SwiftData

/// Settings sheet for editing a folder's RDP profile defaults.
/// Opened from the folder context menu: "Edit RDP Defaults…"
///
/// Design: "inherit from parent" is the default state — represented by the *absence* of data.
/// Setting the toggle to "Inherit" clears `folder.rdpDefaultsData`, propagating up to the parent.
struct FolderDefaultsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let folder: Folder

    // Local working copy; only written back to the model on Save
    @State private var inheriting: Bool = true
    @State private var defaults: RDPProfileDefaults = .global

    // For the "diff from parent" display
    @State private var parentEffective: RDPProfileDefaults = .global

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Inherit from Parent Folder", isOn: $inheriting)
                        .onChange(of: inheriting) { _, on in
                            if on { defaults = parentEffective }
                        }

                    if !inheriting {
                        // Show which fields differ from parent for premium "Overriding: …" feel
                        let overridingFields = defaults.diff(from: parentEffective)
                        if !overridingFields.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Overriding:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(overridingFields.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } header: {
                    Text("RDP Defaults")
                } footer: {
                    if inheriting {
                        Text("Connections inside this folder will use parent folder defaults (or global defaults if no parent overrides exist).")
                    } else {
                        Text("Settings below override parent folder defaults for all connections in this folder that don't set their own overrides.")
                    }
                }

                if !inheriting {
                    Section("Network") {
                        LabeledContent("Port") {
                            TextField("Port", value: $defaults.port, format: .number)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }

                        Picker("Color Depth", selection: $defaults.colorDepth) {
                            ForEach(RDPColorDepth.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                    }

                    Section("Security") {
                        Toggle("Require NLA", isOn: $defaults.enableNLA)
                    }

                    Section("Gateway") {
                        Picker("Mode", selection: $defaults.gatewayMode) {
                            ForEach(GatewayMode.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                        Toggle("Bypass Gateway for Local Addresses", isOn: $defaults.gatewayBypassLocal)
                    }

                    Section("Clipboard") {
                        Toggle("Enable Clipboard", isOn: $defaults.enableClipboard)
                    }

                    Section("Display") {
                        Picker("Scaling", selection: $defaults.scaling) {
                            ForEach(RDPScalingMode.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                        Toggle("Dynamic Resolution", isOn: $defaults.dynamicResolution)
                    }

                    Section("Reconnect") {
                        Stepper("Max Attempts: \(defaults.reconnectMaxAttempts)",
                                value: $defaults.reconnectMaxAttempts, in: 0...20)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Folder Defaults")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                }
            }
            .frame(width: 460, height: 560)
            .onAppear { loadCurrentState() }
        }
    }

    // MARK: - Private

    private func loadCurrentState() {
        inheriting = (folder.rdpDefaultsData == nil)
        defaults = folder.rdpDefaults ?? .global

        // Build parent effective config for diff display
        let parentChain = buildFolderChain(from: folder.parentFolder)
        parentEffective = resolveRDPConfig(
            connection: _DummyConnection(),
            folderChain: parentChain,
            global: .global
        )
    }

    private func save() {
        if inheriting {
            folder.rdpDefaultsData = nil
        } else {
            folder.rdpDefaults = defaults.validated()
        }
        try? modelContext.save()
    }
}

/// Lightweight placeholder used when building parent effective config without a real connection.
private struct _DummyConnection {
    var rdpOverrides: RDPOverrides { RDPOverrides() }
    var folder: Folder? { nil }
}

// Make _DummyConnection work with the resolver by making it conform to the same interface.
// We do this by overloading resolveRDPConfig to accept any type that exposes rdpOverrides.
private func resolveRDPConfig(
    connection: _DummyConnection,
    folderChain: [Folder],
    global: RDPProfileDefaults
) -> RDPProfileDefaults {
    var result = global
    for folder in folderChain {
        if let d = folder.rdpDefaults { result = d }
    }
    return result.applying(connection.rdpOverrides).validated()
}

private extension RDPProfileDefaults {
    func applying(_ overrides: RDPOverrides) -> RDPProfileDefaults { self }
}
