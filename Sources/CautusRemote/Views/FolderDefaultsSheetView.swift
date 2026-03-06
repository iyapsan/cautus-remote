import SwiftUI
import SwiftData

/// Settings sheet for editing a folder's RDP profile defaults.
/// Opened via the folder context menu: "Edit RDP Defaults…"
///
/// UX design: Always show effective values first. A "Customize for this folder"
/// button activates editing. "Reset to Parent" clears defaults and re-inherits.
/// The screen is never empty or confusing.
struct FolderDefaultsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let folder: Folder

    // Local working copy of defaults for this folder
    @State private var isCustomizing: Bool = false
    @State private var defaults: RDPProfileDefaults = .global

    // What the parent chain resolves to (shown when not customizing)
    @State private var parentEffective: RDPProfileDefaults = .global
    @State private var parentSourceName: String = "Global"

    var body: some View {
        NavigationStack {
            Form {
                // ── Status Section: always visible, explains current state ──
                statusSection

                // ── Values: always show effective values ──
                if isCustomizing {
                    customizationForm
                } else {
                    readonlyEffectiveSummary
                }
            }
            .formStyle(.grouped)
            .navigationTitle("\(folder.name) — RDP Defaults")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                }
            }
            .frame(width: 460, height: 520)
            .onAppear { loadState() }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section {
            if isCustomizing {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Custom Defaults Active")
                            .font(.headline)
                        Text("These settings apply to all connections in this folder unless overridden at the connection level.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset to Parent") {
                        withAnimation {
                            isCustomizing = false
                            defaults = parentEffective
                        }
                    }
                    .foregroundStyle(.orange)
                }
                .padding(.vertical, 2)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Using Parent Defaults")
                            .font(.headline)
                        Text("Inherited from: \(parentSourceName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Customize for this Folder") {
                        withAnimation {
                            defaults = parentEffective
                            isCustomizing = true
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Read-only effective summary (when not customizing)

    private var readonlyEffectiveSummary: some View {
        Section("Effective Values — from \(parentSourceName)") {
            effectiveRow("Port", value: "\(parentEffective.port)")
            effectiveRow("Color Depth", value: parentEffective.colorDepth.displayName)
            effectiveRow("Scaling", value: parentEffective.scaling.displayName)
            effectiveRow("Clipboard", value: parentEffective.enableClipboard ? "Enabled" : "Disabled")
            effectiveRow("NLA", value: parentEffective.enableNLA ? "Required" : "Not required")
            effectiveRow("Gateway Mode", value: parentEffective.gatewayMode.displayName)
            effectiveRow("Dynamic Resolution", value: parentEffective.dynamicResolution ? "On" : "Off")
            effectiveRow("Max Reconnects", value: "\(parentEffective.reconnectMaxAttempts)")
        }
    }

    private func effectiveRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Customization Form

    private var customizationForm: some View {
        Group {
            Section("Network") {
                LabeledContent("Port") {
                    TextField("Port", value: $defaults.port, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Color Depth") {
                    Picker("", selection: $defaults.colorDepth) {
                        ForEach(RDPColorDepth.allCases, id: \.self) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    .labelsHidden()
                }
            }

            Section("Display") {
                Picker("Scaling", selection: $defaults.scaling) {
                    ForEach(RDPScalingMode.allCases, id: \.self) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                Toggle("Dynamic Resolution", isOn: $defaults.dynamicResolution)
            }

            Section("Security") {
                Toggle("Require NLA", isOn: $defaults.enableNLA)
            }

            Section("Gateway") {
                Picker("Gateway Mode", selection: $defaults.gatewayMode) {
                    ForEach(GatewayMode.allCases, id: \.self) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                Toggle("Bypass Local Addresses", isOn: $defaults.gatewayBypassLocal)
            }

            Section("Clipboard") {
                Toggle("Clipboard Sync", isOn: $defaults.enableClipboard)
            }

            Section("Reconnect") {
                Stepper("Max Attempts: \(defaults.reconnectMaxAttempts)",
                        value: $defaults.reconnectMaxAttempts, in: 0...20)
            }
        }
    }

    // MARK: - Save / Load

    private func loadState() {
        // Build what the parent chain resolves to (no defaults from this folder)
        let parentChain = buildFolderChain(from: folder.parentFolder)
        parentEffective = parentChain.reduce(RDPProfileDefaults.global) { acc, f in
            f.rdpDefaults ?? acc
        }.validated()
        parentSourceName = folder.parentFolder?.name ?? "Global"

        // Determine if this folder has its own defaults
        if let existing = folder.rdpDefaults {
            defaults = existing
            isCustomizing = true
        } else {
            defaults = parentEffective
            isCustomizing = false
        }
    }

    private func save() {
        if isCustomizing {
            folder.rdpDefaults = defaults.validated()
        } else {
            folder.rdpDefaultsData = nil // clear → inherit
        }
        try? modelContext.save()
    }
}
