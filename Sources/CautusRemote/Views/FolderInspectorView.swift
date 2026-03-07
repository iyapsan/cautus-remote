import SwiftUI
import SwiftData

/// Inspector view for Folder RDP Defaults.
///
/// Modifies the associated `Folder` in place using immediate/debounced commits.
/// Preserves the policy-layer mode switch model (Inherit vs Customize).
struct FolderInspectorView: View {
    let folder: Folder
    
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    @State private var isCustomizing: Bool = false
    @State private var editingPatch: RDPPatch = RDPPatch()
    @State private var parentResolved: RDPResolvedConfig = .global
    @State private var parentSourceName: String = "Global"

    // Helper property to get the resolved config based on customization state
    private var resolved: RDPResolvedConfig {
        isCustomizing
            ? parentResolved.applying(editingPatch).validated()
            : parentResolved
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorHeaderView(
                title: folder.name,
                subtitle: isCustomizing ? "Custom Defaults Active" : "Using Parent Defaults",
                icon: "folder.fill"
            )
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    statusSection
                    
                    if isCustomizing {
                        customizationSection
                    } else {
                        effectiveValuesSection
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { loadState() }
        .onChange(of: folder.id) { _, _ in loadState() } // Reload if selection changes but view is reused
    }
    
    // MARK: - Status Banner
    
    private var statusSection: some View {
        SectionCard(nil) {
            if isCustomizing {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Custom Defaults Active").font(.headline)
                        let count = editingPatch.activeFieldCount
                        Text("Overrides Active (\(count))")
                            .font(.caption).foregroundStyle(.orange) +
                        Text(" • \(parentSourceName)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Reset to Parent") {
                        withAnimation {
                            isCustomizing = false
                            editingPatch = RDPPatch()
                            save() // commit reset
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Using Parent Defaults").font(.headline)
                        Text("Overrides Active (0) • Inherited from \(parentSourceName)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Customize for this Folder") {
                        withAnimation {
                            isCustomizing = true
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Effective Values (Read-Only)
    
    private var effectiveValuesSection: some View {
        SectionCard("Effective Values — from \(parentSourceName)") {
            effectiveRow("Port", value: "\(resolved.port)")
            effectiveRow("Color Depth", value: resolved.colorDepth.displayName)
            effectiveRow("Scaling", value: resolved.scaling.displayName)
            effectiveRow("Auto Resize Display", value: resolved.dynamicResolution ? "On" : "Off")
            effectiveRow("Clipboard Sharing", value: resolved.clipboardEnabled ? "Enabled" : "Disabled")
            effectiveRow("NLA", value: resolved.nlaRequired ? "Required" : "Not required")
            effectiveRow("Gateway Mode", value: resolved.gatewayMode.displayName)
            effectiveRow("Bypass Local", value: resolved.gatewayBypassLocal ? "On" : "Off")
            effectiveRow("Audio", value: resolved.audioEnabled ? "On" : "Off")
            effectiveRow("Drive Redirection", value: resolved.driveRedirectionEnabled ? "On" : "Off")
            effectiveRow("Reconnect Attempts", value: "\(resolved.reconnectAttempts)")
        }
    }
    
    private func effectiveRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).foregroundStyle(.primary)
        }
    }
    
    // MARK: - Customization Section (Editable)
    
    private var customizationSection: some View {
        SectionCard("Customize — overrides parent") {
            // Port
            patchToggleRow("Port", isSet: editingPatch.port != nil,
                onEnable: { editingPatch.port = parentResolved.port; save() },
                onDisable: { editingPatch.port = nil; save() }
            ) {
                TextField("Port", text: Binding(
                    get: { "\(editingPatch.port ?? parentResolved.port)" },
                    set: {
                        if let port = Int($0) {
                            editingPatch.port = port
                        }
                    }
                ))
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
                .onSubmit { save() }
            }
            
            // Color Depth
            patchToggleRow("Color Depth", isSet: editingPatch.colorDepth != nil,
                onEnable: { editingPatch.colorDepth = parentResolved.colorDepth; save() },
                onDisable: { editingPatch.colorDepth = nil; save() }
            ) {
                Picker("", selection: Binding(
                    get: { editingPatch.colorDepth ?? parentResolved.colorDepth },
                    set: { editingPatch.colorDepth = $0; save() }
                )) {
                    ForEach(RDPColorDepth.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }.labelsHidden()
            }
            
            // Scaling
            patchToggleRow("Scaling", isSet: editingPatch.scaling != nil,
                onEnable: { editingPatch.scaling = parentResolved.scaling; save() },
                onDisable: { editingPatch.scaling = nil; save() }
            ) {
                Picker("", selection: Binding(
                    get: { editingPatch.scaling ?? parentResolved.scaling },
                    set: { editingPatch.scaling = $0; save() }
                )) {
                    ForEach(RDPScalingMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }.labelsHidden()
            }
            
            // Auto Resize Display
            patchToggleRow("Auto Resize Display", isSet: editingPatch.dynamicResolution != nil,
                onEnable: { editingPatch.dynamicResolution = parentResolved.dynamicResolution; save() },
                onDisable: { editingPatch.dynamicResolution = nil; save() }
            ) {
                Toggle("", isOn: Binding(
                    get: { editingPatch.dynamicResolution ?? parentResolved.dynamicResolution },
                    set: { editingPatch.dynamicResolution = $0; save() }
                )).labelsHidden()
            }
            
            // Clipboard Sharing
            patchToggleRow("Clipboard Sharing", isSet: editingPatch.clipboardEnabled != nil,
                onEnable: { editingPatch.clipboardEnabled = parentResolved.clipboardEnabled; save() },
                onDisable: { editingPatch.clipboardEnabled = nil; save() }
            ) {
                Toggle("", isOn: Binding(
                    get: { editingPatch.clipboardEnabled ?? parentResolved.clipboardEnabled },
                    set: { editingPatch.clipboardEnabled = $0; save() }
                )).labelsHidden()
            }
            
            // NLA
            patchToggleRow("Require NLA", isSet: editingPatch.nlaRequired != nil,
                onEnable: { editingPatch.nlaRequired = parentResolved.nlaRequired; save() },
                onDisable: { editingPatch.nlaRequired = nil; save() }
            ) {
                Toggle("", isOn: Binding(
                    get: { editingPatch.nlaRequired ?? parentResolved.nlaRequired },
                    set: { editingPatch.nlaRequired = $0; save() }
                )).labelsHidden()
            }
            
            // Gateway Mode
            patchToggleRow("Gateway Mode", isSet: editingPatch.gatewayMode != nil,
                onEnable: { editingPatch.gatewayMode = parentResolved.gatewayMode; save() },
                onDisable: { editingPatch.gatewayMode = nil; save() }
            ) {
                Picker("", selection: Binding(
                    get: { editingPatch.gatewayMode ?? parentResolved.gatewayMode },
                    set: { editingPatch.gatewayMode = $0; save() }
                )) {
                    ForEach(GatewayMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }.labelsHidden()
            }
            
            // Reconnect Attempts
            patchToggleRow("Reconnect Attempts", isSet: editingPatch.reconnectAttempts != nil,
                onEnable: { editingPatch.reconnectAttempts = parentResolved.reconnectAttempts; save() },
                onDisable: { editingPatch.reconnectAttempts = nil; save() }
            ) {
                Stepper("\(editingPatch.reconnectAttempts ?? parentResolved.reconnectAttempts)",
                    value: Binding(
                        get: { editingPatch.reconnectAttempts ?? parentResolved.reconnectAttempts },
                        set: { editingPatch.reconnectAttempts = $0; save() }
                    ), in: 0...20)
            }
            
            // Audio
            patchToggleRow("Audio", isSet: editingPatch.audioEnabled != nil,
                onEnable: { editingPatch.audioEnabled = parentResolved.audioEnabled; save() },
                onDisable: { editingPatch.audioEnabled = nil; save() }
            ) {
                Toggle("", isOn: Binding(
                    get: { editingPatch.audioEnabled ?? parentResolved.audioEnabled },
                    set: { editingPatch.audioEnabled = $0; save() }
                )).labelsHidden()
            }
            
            // Drive Redirection
            patchToggleRow("Drive Redirection", isSet: editingPatch.driveRedirectionEnabled != nil,
                onEnable: { editingPatch.driveRedirectionEnabled = parentResolved.driveRedirectionEnabled; save() },
                onDisable: { editingPatch.driveRedirectionEnabled = nil; save() }
            ) {
                Toggle("", isOn: Binding(
                    get: { editingPatch.driveRedirectionEnabled ?? parentResolved.driveRedirectionEnabled },
                    set: { editingPatch.driveRedirectionEnabled = $0; save() }
                )).labelsHidden()
            }
        }
    }
    
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

private extension RDPPatch {
    var activeFieldCount: Int {
        let items: [Any?] = [port, colorDepth, scaling, dynamicResolution, clipboardEnabled,
         nlaRequired, gatewayMode, gatewayBypassLocal, reconnectAttempts,
         audioEnabled, driveRedirectionEnabled]
        return items.compactMap { $0 }.count
    }
}
