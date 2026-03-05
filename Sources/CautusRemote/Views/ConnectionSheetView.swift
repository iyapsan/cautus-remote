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
    @State private var password: (() -> String)? = { "" } // Stub for keychain loading
    @State private var rawPasswordInput: String = ""

    // Gateway Fields
    @State private var useGateway: Bool = false
    @State private var gatewayUrl: String = ""
    @State private var gatewayUsername: String = ""
    @State private var ignoreCertificateErrors: Bool = false

    // State
    @State private var isAdvancedExpanded: Bool = false
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Connection Name", text: $name)
                    TextField("Host (IP or FQDN)", text: $host)
                    TextField("Port", text: $port)
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
            }
            .formStyle(.grouped)
            .navigationTitle(appState.editingConnection != nil ? "Edit Connection" : "New Connection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConnection()
                    }
                    .disabled(name.isEmpty || host.isEmpty || username.isEmpty)
                }
            }
            .frame(width: 450, height: 480)
            .onAppear {
                if let editing = appState.editingConnection {
                    name = editing.name
                    host = editing.host
                    port = String(editing.port)
                    username = editing.username
                    gatewayUrl = editing.gatewayUrl ?? ""
                    gatewayUsername = editing.gatewayUsername ?? ""
                    useGateway = !gatewayUrl.isEmpty
                    ignoreCertificateErrors = editing.ignoreCertificateErrors
                    // TODO: Load password from keychain using appState.keychainService
                }
            }
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
            modelContext.insert(newConnection)
            targetConnection = newConnection
        }
        
        // Save password to Keychain
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
