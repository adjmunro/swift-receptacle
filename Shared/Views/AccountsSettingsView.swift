import SwiftUI
import Receptacle

// MARK: - AccountsSettingsView

/// Settings pane for managing IMAP email accounts.
///
/// Non-secret config (host, port, username) persists in UserDefaults as JSON.
/// Passwords and OAuth tokens live in the Keychain via `KeychainHelper`.
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
                            let acct = accounts[index]
                            try? KeychainHelper.delete(
                                account: KeychainHelper.passwordKey(accountId: acct.accountId))
                            Task { try? await OAuthManager.shared.signOut(
                                provider: .google, accountId: acct.accountId) }
                        }
                        accounts.remove(atOffsets: offsets)
                        persist()
                    }
                }
                .listStyle(.bordered)
            }

            Divider()

            // Finder-style bottom toolbar
            HStack(spacing: 0) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus").frame(width: 28, height: 28)
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
                Text(account.displayName).font(.headline)
                Text(account.username).font(.caption).foregroundStyle(.secondary)
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

    // Password-auth fields (iCloud, custom IMAP)
    @State private var password = ""
    @State private var customHost = ""
    @State private var customPort = "993"
    @State private var customTLS = true

    // Gmail OAuth2 state
    @State private var googleClientId = UserDefaults.standard.string(forKey: "google.oauth.clientId") ?? ""
    @State private var isSigningIn = false
    @State private var signedIn = false
    @State private var signedInEmail = ""
    @State private var pendingAccountId = ""
    @State private var signInError: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
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
                    .onChange(of: providerType) { _, _ in resetOAuthState() }
                }

                Section("Account") {
                    TextField("Account name", text: $displayName)

                    switch providerType {
                    case .gmail:
                        gmailFields
                    case .iCloud:
                        iCloudFields
                    case .outlook:
                        outlookFields
                    case .custom:
                        customFields
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

            // Error banner
            if let err = signInError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Dismiss") { signInError = nil }
                        .font(.caption)
                        .buttonStyle(.borderless)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.08))
            }

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
        .frame(width: 480, height: providerType == .gmail ? 500 : 420)
    }

    // MARK: - Provider-specific fields

    @ViewBuilder
    private var gmailFields: some View {
        TextField("Email address (hint)", text: $username)
            .textContentType(.emailAddress)

        TextField("Google Client ID", text: $googleClientId)
            .textContentType(.none)

        // Inline instructions
        VStack(alignment: .leading, spacing: 4) {
            Text("How to get a Client ID:")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("1. Go to console.cloud.google.com")
                .font(.caption).foregroundStyle(.secondary)
            Text("2. APIs & Services → Credentials → Create OAuth 2.0 Client ID")
                .font(.caption).foregroundStyle(.secondary)
            Text("3. Choose \"Desktop app\"")
                .font(.caption).foregroundStyle(.secondary)
            Text("4. Also set GOOGLE_REVERSED_CLIENT_ID in Xcode Build Settings")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 2)

        // Sign-in button / status
        if isSigningIn {
            HStack {
                ProgressView().controlSize(.small)
                Text("Signing in with Google…").foregroundStyle(.secondary)
            }
        } else if signedIn {
            Label(signedInEmail, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Button {
                Task { await performGoogleSignIn() }
            } label: {
                Label("Sign in with Google", systemImage: "globe")
            }
            .disabled(displayName.isEmpty || googleClientId.isEmpty)
        }
    }

    @ViewBuilder
    private var iCloudFields: some View {
        TextField("Apple ID (e.g. you@icloud.com)", text: $username)
            .textContentType(.emailAddress)
        SecureField("App-specific password", text: $password)
        Text("Generate at appleid.apple.com → Security → App-Specific Passwords.")
            .font(.caption).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var outlookFields: some View {
        TextField("Email address", text: $username)
            .textContentType(.emailAddress)
        Label("Microsoft OAuth2 sign-in coming in Phase 4.", systemImage: "info.circle")
            .font(.caption).foregroundStyle(.orange)
    }

    @ViewBuilder
    private var customFields: some View {
        TextField("Email / Username", text: $username)
            .textContentType(.emailAddress)
        SecureField("Password", text: $password)
    }

    // MARK: - Validation

    private var canAdd: Bool {
        guard !displayName.isEmpty else { return false }
        switch providerType {
        case .gmail:   return signedIn
        case .iCloud:  return !username.isEmpty && !password.isEmpty
        case .outlook: return false  // OAuth2 not yet implemented
        case .custom:  return !username.isEmpty && !password.isEmpty && !customHost.isEmpty
        }
    }

    // MARK: - Actions

    @MainActor
    private func performGoogleSignIn() async {
        isSigningIn = true
        signInError = nil
        let tempId = UUID().uuidString
        do {
            await OAuthManager.shared.configure(googleClientId: googleClientId)
            let email = try await OAuthManager.shared.signIn(
                provider: .google,
                accountId: tempId,
                hint: username.isEmpty ? nil : username
            )
            signedInEmail = email
            if username.isEmpty { username = email }
            pendingAccountId = tempId
            signedIn = true
        } catch OAuthError.userCancelled {
            // No error — user just dismissed the browser
        } catch {
            signInError = error.localizedDescription
        }
        isSigningIn = false
    }

    private func addAccount() {
        let id = pendingAccountId.isEmpty ? UUID().uuidString : pendingAccountId
        let finalUsername = signedIn ? signedInEmail : username
        let config = IMAPAccountConfig(
            accountId: id,
            displayName: displayName,
            providerType: providerType,
            host: providerType == .custom && !customHost.isEmpty ? customHost : nil,
            port: providerType == .custom ? Int(customPort) : nil,
            useTLS: providerType == .custom ? customTLS : nil,
            username: finalUsername
        )
        if !password.isEmpty {
            try? KeychainHelper.save(password,
                account: KeychainHelper.passwordKey(accountId: id))
        }
        onAdd(config)
        dismiss()
    }

    private func resetOAuthState() {
        signedIn = false
        signedInEmail = ""
        pendingAccountId = ""
        signInError = nil
    }
}
