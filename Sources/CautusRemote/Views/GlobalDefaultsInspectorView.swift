import SwiftUI

/// Inspector view for editing app-wide (global) RDP defaults.
///
/// Refactored from `GlobalDefaultsSheetView` to support inline editing.
/// Uses immediate commit for toggles/pickers and immediate or debounced
/// commit for text/numeric fields.
struct GlobalDefaultsInspectorView: View {
    @Environment(AppState.self) private var appState

    // State is synchronized directly with appState via bindings.
    // Unlike the sheet, we don't use a local copy and explicit Save/Revert.
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 0) {
            // Header
            InspectorHeaderView(
                title: "Global Defaults",
                subtitle: "Applies to all connections unless overridden by folders or connections",
                icon: "globe"
            )
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    
                    // ── Network ─────────────────────────────────────────────────────────
                    SectionCard("Network") {
                        LabeledContent("Port") {
                            // Use direct binding to appState
                            TextField("Port", text: Binding(
                                get: { "\(state.globalRDPDefaults.port)" },
                                set: { state.globalRDPDefaults.port = Int($0) ?? state.globalRDPDefaults.port }
                            ))
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                        }
                        
                        LabeledContent("Color Depth") {
                            Picker("", selection: $state.globalRDPDefaults.colorDepth) {
                                ForEach(RDPColorDepth.allCases, id: \.self) {
                                    Text($0.displayName).tag($0)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    
                    // ── Display ─────────────────────────────────────────────────────────
                    SectionCard("Display") {
                        Picker("Scaling", selection: $state.globalRDPDefaults.scaling) {
                            ForEach(RDPScalingMode.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                        Toggle("Auto Resize Display", isOn: $state.globalRDPDefaults.dynamicResolution)
                    }
                    
                    // ── Security ────────────────────────────────────────────────────────
                    SectionCard("Security") {
                        Toggle("Require NLA", isOn: $state.globalRDPDefaults.nlaRequired)
                    }
                    
                    // ── Gateway ─────────────────────────────────────────────────────────
                    SectionCard("Gateway") {
                        Picker("Gateway Mode", selection: $state.globalRDPDefaults.gatewayMode) {
                            ForEach(GatewayMode.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                        Toggle("Bypass Local Addresses", isOn: $state.globalRDPDefaults.gatewayBypassLocal)
                    }
                    
                    // ── Clipboard ───────────────────────────────────────────────────────
                    SectionCard("Clipboard") {
                        Toggle("Clipboard Sharing", isOn: $state.globalRDPDefaults.clipboardEnabled)
                    }
                    
                    // ── Redirection ─────────────────────────────────────────────────────
                    SectionCard("Redirection") {
                        Toggle("Enable Audio Output", isOn: $state.globalRDPDefaults.audioEnabled)
                        Toggle("Enable Drive Redirection", isOn: $state.globalRDPDefaults.driveRedirectionEnabled)
                    }
                    
                    // ── Connection Behavior ─────────────────────────────────────────────
                    SectionCard("Connection Behavior") {
                        Stepper("Reconnect Attempts: \(state.globalRDPDefaults.reconnectAttempts)",
                                value: $state.globalRDPDefaults.reconnectAttempts, in: 0...20)
                    }
                    
                    // ── Reset ───────────────────────────────────────────────────────────
                    SectionCard(nil) {
                        Button("Restore Default Settings") {
                            withAnimation {
                                state.globalRDPDefaults = .global
                            }
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
    }
}
