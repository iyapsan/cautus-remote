import SwiftUI

/// Editor for app-wide (global) RDP defaults.
///
/// Entry point: right-click the "Connections" section header → "Edit Global Defaults…"
///
/// The global config is the baseline for the entire resolution chain:
///   Global → Folder patches → Connection patch → RDPResolvedConfig
///
/// Stored in UserDefaults as JSON — no SwiftData schema involved.
struct GlobalDefaultsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var config: RDPResolvedConfig = .global

    var body: some View {
        NavigationStack {
            Form {
                // ── Scope banner ────────────────────────────────────────────────────
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Global Defaults")
                                .font(.headline)
                            Text("These values apply to all connections unless overridden by a folder or connection.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // ── Network ─────────────────────────────────────────────────────────
                Section("Network") {
                    LabeledContent("Port") {
                        // String binding — avoids comma formatting (3389, never 3,389)
                        TextField("Port", text: Binding(
                            get: { "\(config.port)" },
                            set: { config.port = Int($0) ?? config.port }
                        ))
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Color Depth") {
                        Picker("", selection: $config.colorDepth) {
                            ForEach(RDPColorDepth.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }.labelsHidden()
                    }
                }

                // ── Display ─────────────────────────────────────────────────────────
                Section("Display") {
                    Picker("Scaling", selection: $config.scaling) {
                        ForEach(RDPScalingMode.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    Toggle("Auto Resize Display", isOn: $config.dynamicResolution)
                }

                // ── Security ────────────────────────────────────────────────────────
                Section("Security") {
                    Toggle("Require NLA", isOn: $config.nlaRequired)
                }

                // ── Gateway ─────────────────────────────────────────────────────────
                Section("Gateway") {
                    Picker("Gateway Mode", selection: $config.gatewayMode) {
                        ForEach(GatewayMode.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    Toggle("Bypass Local Addresses", isOn: $config.gatewayBypassLocal)
                }

                // ── Clipboard ───────────────────────────────────────────────────────
                Section("Clipboard") {
                    Toggle("Clipboard Sharing", isOn: $config.clipboardEnabled)
                }

                // ── Redirection ─────────────────────────────────────────────────────
                Section("Redirection") {
                    Toggle("Enable Audio Output", isOn: $config.audioEnabled)
                    Toggle("Enable Drive Redirection", isOn: $config.driveRedirectionEnabled)
                }

                // ── Connection Behavior ─────────────────────────────────────────────
                Section("Connection Behavior") {
                    Stepper("Reconnect Attempts: \(config.reconnectAttempts)",
                            value: $config.reconnectAttempts, in: 0...20)
                }

                // ── Reset ───────────────────────────────────────────────────────────
                Section {
                    Button("Restore Default Settings") {
                        withAnimation { config = .global }
                    }
                    .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Global Defaults")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .frame(width: 440, height: 560)
            .onAppear { config = appState.globalRDPDefaults }
        }
    }

    private func save() {
        appState.globalRDPDefaults = config
        dismiss()
    }
}
