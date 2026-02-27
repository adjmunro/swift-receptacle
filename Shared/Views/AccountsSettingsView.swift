import SwiftUI
import Receptacle

// MARK: - AccountsSettingsView

/// Settings pane for managing IMAP email accounts.
///
/// Non-secret config (host, port, username) persists in UserDefaults as JSON.
/// Passwords and OAuth tokens live in the Keychain via `KeychainHelper`.
///
/// OAuth2 sign-in for Gmail and Outlook will be wired in Phase 4.
struct AccountsSettingsView: View {
    @State private var accounts: [IMAPAccountConfig] = []
    @State private var showingAdd = false

    var body: some View {
        VStack(spacing: 0) {
            if accounts.isEmpty {
                ContentUnavailableView(
                    "No Accounts",
                    systemImage: "envelope.badge.shield.half.filled",
                    description: Text("Add an email account to start syncing.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(accounts, id: \.accountId) { account in
                        AccountRowView(account: account)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            try? KeychainHelper.delete(
                                account: KeychainHelper.passwordKey(accountId: accounts[index].accountId)
                            )
                        }
                        accounts.remove(atOffsets: offsets)
                        persist()
                    }
                }
                .listStyle(.bordered)
            }

            Divider()

            // Bottom toolbar: + / - buttons (Finder-style)
            HStack(spacing: 0) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .help("Add account")
                .padding(.leading, 4)

                Spacer()
            }
            .frame(height: 30)
        }
        .sheet(isPresented: $showingAdd) {
            AddAccountSheet { newConfig in
                accounts.append(newConfig)
                persist()
            }
        }
        .onAppear { load() }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "imap.accounts"),
              let decoded = try? JSONDecoder().decode([IMAPAccountConfig].self, from: data)
        else { return }
        accounts = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: "imap.accounts")
        }
    }
}

// MARK: - AccountRowView

struct AccountRowView: View {
    let account: IMAPAccountConfig

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName(for: account.providerType))
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.headline)
                Text(account.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(account.providerType.displayName)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func iconName(for type: IMAPProviderType) -> String {
        switch type {
        case .gmail:   return "envelope.circle.fill"
        case .iCloud:  return "icloud.fill"
        case .outlook: return "envelope.fill"
        case .custom:  return "server.rack"
        }
    }
}

// MARK: - AddAccountSheet

struct AddAccountSheet: View {
    let onAdd: (IMAPAccountConfig) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var providerType: IMAPProviderType = .iCloud
    @State private var displayName = ""
    @State private var username = ""
    @State private var password = ""
    @State private var customHost = ""
    @State private var customPort = "993"
    @State private var customTLS = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Add Email Account")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()

            Form {
                Section("Provider") {
                    Picker("Type", selection: $providerType) {
                        ForEach(IMAPProviderType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Account") {
                    TextField("Account name", text: $displayName)
                    TextField("Email address", text: $username)
                        .textContentType(.emailAddress)

                    if providerType.defaultAuthMethod == .password {
                        SecureField(
                            providerType == .iCloud ? "App-specific password" : "Password",
                            text: $password
                        )
                        if providerType == .iCloud {
                            Text("Generate at appleid.apple.com → Security → App-Specific Passwords.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // OAuth2 providers (Gmail, Outlook) — full flow wired in Phase 4
                        Label(
                            "OAuth2 sign-in for \(providerType.displayName) will be added in Phase 4.",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }

                if providerType == .custom {
                    Section("Server") {
                        TextField("IMAP host (e.g. mail.example.com)", text: $customHost)
                        TextField("Port", text: $customPort)
                        Toggle("Use TLS (IMAPS, port 993)", isOn: $customTLS)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Add Account") { addAccount() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAdd)
                    .keyboardShortcut(.defaultAction)
                    .padding(16)
            }
        }
        .frame(width: 460, height: 420)
    }

    private var canAdd: Bool {
        !displayName.isEmpty
            && !username.isEmpty
            && (providerType.defaultAuthMethod == .oauth2 || !password.isEmpty)
            && (providerType != .custom || !customHost.isEmpty)
    }

    private func addAccount() {
        let id = UUID().uuidString
        let config = IMAPAccountConfig(
            accountId: id,
            displayName: displayName,
            providerType: providerType,
            host: providerType == .custom && !customHost.isEmpty ? customHost : nil,
            port: providerType == .custom ? Int(customPort) : nil,
            useTLS: providerType == .custom ? customTLS : nil,
            username: username
        )
        if !password.isEmpty {
            try? KeychainHelper.save(password, account: KeychainHelper.passwordKey(accountId: id))
        }
        onAdd(config)
        dismiss()
    }
}
