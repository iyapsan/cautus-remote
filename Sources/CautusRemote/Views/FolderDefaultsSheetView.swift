import SwiftUI
import SwiftData

/// Folder RDP Defaults editor.
///
/// UX: Always shows all effective fields — inherited values are visible and muted.
/// "Customize for this Folder" activates a partial patch editor.
/// "Reset to Parent" clears the patch (folder inherits everything again).
struct FolderDefaultsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let folder: Folder

    @State private var isCustomizing: Bool = false
    // Editing state: what the user is modifying (partial patch, not full config)
    @State private var editingPatch: RDPPatch = RDPPatch()
    // What the parent chain resolves to (concrete, for read-only display)
    @State private var parentResolved: RDPResolvedConfig = .global
    @State private var parentSourceName: String = "Global"

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                effectiveValuesSection
                if isCustomizing { customizationSection }
            }
            .formStyle(.grouped)
            .navigationTitle("\(folder.name) — RDP Defaults")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save(); dismiss() } }
            }
            .frame(width: 480, height: 560)
            .onAppear { loadState() }
        }
    }

    // MARK: - Status Banner

    private var statusSection: some View {
        Section {
            if isCustomizing {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3").font(.title3).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Custom Defaults Active").font(.headline)
                        let count = editingPatch.activeFieldCount
                        Text(count > 0
                             ? "\(count) setting\(count == 1 ? "" : "s") differ from \(parentSourceName)"
                             : "These settings apply to all connections in this folder unless overridden.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset to Parent") {
                        withAnimation { isCustomizing = false; editingPatch = RDPPatch() }
                    }.foregroundStyle(.orange)
                }
                .padding(.vertical, 2)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle").font(.title3).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Using Parent Defaults").font(.headline)
                        Text("Inherited from: \(parentSourceName)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Customize for this Folder") {
                        withAnimation { isCustomizing = true }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Effective Values (always shown, all fields, inherited values muted)

    /// Shows the fully resolved effective config — what connections in this folder *actually* get.
    /// Inherited values shown in muted style; customized values shown in full/orange.
    private var effectiveValuesSection: some View {
        let resolved = isCustomizing
            ? parentResolved.applying(editingPatch).validated()
            : parentResolved

        return Section("Effective Values — from \(parentSourceName)") {
            effectiveRow("Port", value: "\(resolved.port)",
                         overridden: isCustomizing && editingPatch.port != nil)
            effectiveRow("Color Depth", value: resolved.colorDepth.displayName,
                         overridden: isCustomizing && editingPatch.colorDepth != nil)
            effectiveRow("Scaling", value: resolved.scaling.displayName,
                         overridden: isCustomizing && editingPatch.scaling != nil)
            effectiveRow("Auto Resize Display", value: resolved.dynamicResolution ? "On" : "Off",
                         overridden: isCustomizing && editingPatch.dynamicResolution != nil)
            effectiveRow("Clipboard Sharing", value: resolved.clipboardEnabled ? "Enabled" : "Disabled",
                         overridden: isCustomizing && editingPatch.clipboardEnabled != nil)
            effectiveRow("NLA", value: resolved.nlaRequired ? "Required" : "Not required",
                         overridden: isCustomizing && editingPatch.nlaRequired != nil)
            effectiveRow("Gateway Mode", value: resolved.gatewayMode.displayName,
                         overridden: isCustomizing && editingPatch.gatewayMode != nil)
            effectiveRow("Bypass Local", value: resolved.gatewayBypassLocal ? "On" : "Off",
                         overridden: isCustomizing && editingPatch.gatewayBypassLocal != nil)
            effectiveRow("Audio", value: resolved.audioEnabled ? "On" : "Off",
                         overridden: isCustomizing && editingPatch.audioEnabled != nil)
            effectiveRow("Drive Redirection", value: resolved.driveRedirectionEnabled ? "On" : "Off",
                         overridden: isCustomizing && editingPatch.driveRedirectionEnabled != nil)
            effectiveRow("Reconnect Attempts", value: "\(resolved.reconnectAttempts)",
                         overridden: isCustomizing && editingPatch.reconnectAttempts != nil)
        }
    }

    private func effectiveRow(_ label: String, value: String, overridden: Bool) -> some View {
        HStack {
            Text(label).foregroundStyle(overridden ? .primary : .secondary)
            Spacer()
            if overridden { Circle().fill(Color.orange).frame(width: 6, height: 6) }
            Text(value).foregroundStyle(overridden ? .orange : .secondary)
        }
    }

    // MARK: - Customization Section (only shown when isCustomizing)

    private var customizationSection: some View {
        Group {
            Section("Customize — overrides parent for each set field") {
                // Port
                patchToggleRow("Port", isSet: editingPatch.port != nil,
                    onEnable: { editingPatch.port = parentResolved.port },
                    onDisable: { editingPatch.port = nil }
                ) {
                    TextField("Port", text: Binding(
                        get: { "\(editingPatch.port ?? parentResolved.port)" },
                        set: { editingPatch.port = Int($0) }
                    )).frame(width: 80)
                }

                // Color Depth
                patchToggleRow("Color Depth", isSet: editingPatch.colorDepth != nil,
                    onEnable: { editingPatch.colorDepth = parentResolved.colorDepth },
                    onDisable: { editingPatch.colorDepth = nil }
                ) {
                    Picker("", selection: Binding(
                        get: { editingPatch.colorDepth ?? parentResolved.colorDepth },
                        set: { editingPatch.colorDepth = $0 }
                    )) {
                        ForEach(RDPColorDepth.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }.labelsHidden()
                }

                // Scaling
                patchToggleRow("Scaling", isSet: editingPatch.scaling != nil,
                    onEnable: { editingPatch.scaling = parentResolved.scaling },
                    onDisable: { editingPatch.scaling = nil }
                ) {
                    Picker("", selection: Binding(
                        get: { editingPatch.scaling ?? parentResolved.scaling },
                        set: { editingPatch.scaling = $0 }
                    )) {
                        ForEach(RDPScalingMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }.labelsHidden()
                }

                // Auto Resize Display
                patchToggleRow("Auto Resize Display", isSet: editingPatch.dynamicResolution != nil,
                    onEnable: { editingPatch.dynamicResolution = parentResolved.dynamicResolution },
                    onDisable: { editingPatch.dynamicResolution = nil }
                ) {
                    Toggle("", isOn: Binding(
                        get: { editingPatch.dynamicResolution ?? parentResolved.dynamicResolution },
                        set: { editingPatch.dynamicResolution = $0 }
                    )).labelsHidden()
                }

                // Clipboard Sharing
                patchToggleRow("Clipboard Sharing", isSet: editingPatch.clipboardEnabled != nil,
                    onEnable: { editingPatch.clipboardEnabled = parentResolved.clipboardEnabled },
                    onDisable: { editingPatch.clipboardEnabled = nil }
                ) {
                    Toggle("", isOn: Binding(
                        get: { editingPatch.clipboardEnabled ?? parentResolved.clipboardEnabled },
                        set: { editingPatch.clipboardEnabled = $0 }
                    )).labelsHidden()
                }

                // NLA
                patchToggleRow("Require NLA", isSet: editingPatch.nlaRequired != nil,
                    onEnable: { editingPatch.nlaRequired = parentResolved.nlaRequired },
                    onDisable: { editingPatch.nlaRequired = nil }
                ) {
                    Toggle("", isOn: Binding(
                        get: { editingPatch.nlaRequired ?? parentResolved.nlaRequired },
                        set: { editingPatch.nlaRequired = $0 }
                    )).labelsHidden()
                }

                // Gateway Mode
                patchToggleRow("Gateway Mode", isSet: editingPatch.gatewayMode != nil,
                    onEnable: { editingPatch.gatewayMode = parentResolved.gatewayMode },
                    onDisable: { editingPatch.gatewayMode = nil }
                ) {
                    Picker("", selection: Binding(
                        get: { editingPatch.gatewayMode ?? parentResolved.gatewayMode },
                        set: { editingPatch.gatewayMode = $0 }
                    )) {
                        ForEach(GatewayMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }.labelsHidden()
                }

                // Reconnect Attempts
                patchToggleRow("Reconnect Attempts", isSet: editingPatch.reconnectAttempts != nil,
                    onEnable: { editingPatch.reconnectAttempts = parentResolved.reconnectAttempts },
                    onDisable: { editingPatch.reconnectAttempts = nil }
                ) {
                    Stepper("\(editingPatch.reconnectAttempts ?? parentResolved.reconnectAttempts)",
                        value: Binding(
                            get: { editingPatch.reconnectAttempts ?? parentResolved.reconnectAttempts },
                            set: { editingPatch.reconnectAttempts = $0 }
                        ), in: 0...20)
                }

                // Audio
                patchToggleRow("Audio", isSet: editingPatch.audioEnabled != nil,
                    onEnable: { editingPatch.audioEnabled = parentResolved.audioEnabled },
                    onDisable: { editingPatch.audioEnabled = nil }
                ) {
                    Toggle("", isOn: Binding(
                        get: { editingPatch.audioEnabled ?? parentResolved.audioEnabled },
                        set: { editingPatch.audioEnabled = $0 }
                    )).labelsHidden()
                }

                // Drive Redirection
                patchToggleRow("Drive Redirection", isSet: editingPatch.driveRedirectionEnabled != nil,
                    onEnable: { editingPatch.driveRedirectionEnabled = parentResolved.driveRedirectionEnabled },
                    onDisable: { editingPatch.driveRedirectionEnabled = nil }
                ) {
                    Toggle("", isOn: Binding(
                        get: { editingPatch.driveRedirectionEnabled ?? parentResolved.driveRedirectionEnabled },
                        set: { editingPatch.driveRedirectionEnabled = $0 }
                    )).labelsHidden()
                }
            }
        }
    }

    /// A row that has an "Override" checkbox: when off the value is grayed out from parent, when on the control is live.
    @ViewBuilder
    private func patchToggleRow<Content: View>(
        _ label: String,
        isSet: Bool,
        onEnable: @escaping () -> Void,
        onDisable: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        HStack {
            Toggle("", isOn: Binding(get: { isSet }, set: { if $0 { onEnable() } else { onDisable() } }))
                .labelsHidden()
                .toggleStyle(.checkbox)
            Text(label).foregroundStyle(isSet ? .primary : .secondary)
            Spacer()
            if isSet { content() }
        }
    }

    // MARK: - Load / Save

    private func loadState() {
        // Resolve parent chain using canonical buildFolderChain(for:) — no local duplicate
        let parentChain = buildFolderChain(for: folder.parentFolder)
        parentResolved = parentChain.reduce(RDPResolvedConfig.global) { acc, f in
            f.rdpPatch.map { acc.applying($0) } ?? acc
        }.validated()
        parentSourceName = folder.parentFolder?.name ?? "Global"

        if let existing = folder.rdpPatch {
            editingPatch = existing
            isCustomizing = true
        } else {
            editingPatch = RDPPatch()
            isCustomizing = false
        }
    }

    private func save() {
        folder.rdpPatch = isCustomizing && !editingPatch.isEmpty ? editingPatch : nil
        try? modelContext.save()
    }
}

// MARK: - RDPPatch helper: count of active (non-nil) fields

private extension RDPPatch {
    var activeFieldCount: Int {
        [port, colorDepth, scaling, dynamicResolution, clipboardEnabled,
         nlaRequired, gatewayMode, gatewayBypassLocal, reconnectAttempts]
            .filter { $0 != nil }.count
    }
}
