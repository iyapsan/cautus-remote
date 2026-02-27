import SwiftUI

/// Sheet for creating or editing a connection.
///
/// Includes fields for name, host, port, username, authentication,
/// SSH key path, and folder assignment.
struct ConnectionFormView: View {
    let connection: Connection?
    var initialFolderId: UUID? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var name = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var authMethod: AuthMethod = .password
    @State private var password = ""
    @State private var sshKeyPath = ""
    @State private var isFavorite = false
    @State private var selectedFolderId: UUID?

    private var isEditing: Bool { connection != nil }
    private var title: String { isEditing ? "Edit Connection" : "New Connection" }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Int(port) ?? 0) > 0 && (Int(port) ?? 0) <= 65535
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Form
            ScrollView {
                VStack(spacing: 20) {
                    // Basic info
                    GroupBox("Connection") {
                        VStack(spacing: 12) {
                            LabeledField("Name") {
                                TextField("My Server", text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack(spacing: 12) {
                                LabeledField("Host") {
                                    TextField("example.com", text: $host)
                                        .textFieldStyle(.roundedBorder)
                                }
                                LabeledField("Port", width: 80) {
                                    TextField("22", text: $port)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            LabeledField("Username") {
                                TextField("root", text: $username)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(12)
                    }

                    // Authentication
                    GroupBox("Authentication") {
                        VStack(spacing: 12) {
                            Picker("Method", selection: $authMethod) {
                                Text("Password").tag(AuthMethod.password)
                                Text("SSH Key").tag(AuthMethod.publicKey)
                            }
                            .pickerStyle(.segmented)

                            if authMethod == .password {
                                LabeledField("Password") {
                                    SecureField("Enter password", text: $password)
                                        .textFieldStyle(.roundedBorder)
                                }
                            } else {
                                LabeledField("Key Path") {
                                    HStack {
                                        TextField("~/.ssh/id_ed25519", text: $sshKeyPath)
                                            .textFieldStyle(.roundedBorder)

                                        Button("Browse...") {
                                            browseForKey()
                                        }
                                        .controlSize(.small)
                                    }
                                }
                            }
                        }
                        .padding(12)
                    }

                    // Organization
                    GroupBox("Organization") {
                        VStack(spacing: 12) {
                            LabeledField("Folder") {
                                Picker("Folder", selection: $selectedFolderId) {
                                    Text("No Folder").tag(nil as UUID?)
                                    ForEach(appState.connectionService.allFoldersFlattened(), id: \.folder.id) { item in
                                        Text(String(repeating: "  ", count: item.depth) + item.folder.name)
                                            .tag(item.folder.id as UUID?)
                                    }
                                }
                                .labelsHidden()
                            }
                            Toggle("Add to Favorites", isOn: $isFavorite)
                        }
                        .padding(12)
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Create") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(20)
        }
        .frame(width: 460, height: 560)
        .onAppear {
            if let connection {
                name = connection.name
                host = connection.host
                port = String(connection.port)
                username = connection.username
                authMethod = connection.authMethod
                sshKeyPath = connection.sshKeyPath ?? ""
                isFavorite = connection.isFavorite
                selectedFolderId = connection.folder?.id
            } else if let initialFolderId {
                selectedFolderId = initialFolderId
            }
        }
    }

    // MARK: - Actions

    private func save() {
        let conn = connection ?? Connection(
            name: name,
            host: host,
            port: Int(port) ?? 22,
            username: username,
            authMethod: authMethod
        )

        if isEditing {
            conn.name = name
            conn.host = host
            conn.port = Int(port) ?? 22
            conn.username = username
            conn.authMethodRaw = authMethod.rawValue
            conn.sshKeyPath = sshKeyPath.isEmpty ? nil : sshKeyPath
            conn.isFavorite = isFavorite
        } else {
            conn.sshKeyPath = sshKeyPath.isEmpty ? nil : sshKeyPath
            conn.isFavorite = isFavorite
        }

        // Find the selected folder
        var folder: Folder? = nil
        if let folderId = selectedFolderId {
            folder = appState.connectionService.allFoldersFlattened()
                .first(where: { $0.folder.id == folderId })?.folder
        }

        try? appState.connectionService.save(conn, password: password.isEmpty ? nil : password, folder: folder)
        dismiss()
    }

    private func browseForKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".ssh")

        if panel.runModal() == .OK, let url = panel.url {
            sshKeyPath = url.path
        }
    }
}

// MARK: - Labeled Field

/// Consistent form field with label above.
struct LabeledField<Content: View>: View {
    let label: String
    let width: CGFloat?
    let content: () -> Content

    init(_ label: String, width: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.width = width
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(width: width, alignment: .leading)
    }
}
