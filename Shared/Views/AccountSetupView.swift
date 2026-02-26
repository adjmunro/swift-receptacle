#if canImport(SwiftUI)
import SwiftUI
import Receptacle  // IMAPProviderType, IMAPAuthMethod

// MARK: - AccountSetupView

/// Sheet that walks the user through adding a new IMAP account.
///
/// Flow:
///   1. Provider picker (Gmail / iCloud / Outlook / Custom)
///   2. Username / email entry (all providers)
///   3. Auth:
///      - Gmail / Outlook → OAuth2 "Sign in with Google/Microsoft" button
///      - iCloud / Custom → app-specific password field (stored in Keychain)
///   4. Optional: override IMAP host/port for Custom provider
///   5. "Add Account" → validates + saves to Keychain + creates IMAPAccountConfig
///
/// Actual OAuth sign-in (GIDSignIn / MSAL) is wired in Phase 4 Xcode integration.
public struct AccountSetupView: View {

    // Callbacks
    public var onDone: (IMAPAccountConfig) -> Void
    public var onCancel: () -> Void

    // MARK: State

    @State private var selectedProvider: IMAPProviderType = .gmail
    @State private var email: String = ""
    @State private var password: String = ""   // iCloud / Custom only
    @State private var customHost: String = ""
    @State private var customPort: String = "993"
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    public init(onDone: @escaping (IMAPAccountConfig) -> Void,
                onCancel: @escaping () -> Void) {
        self.onDone = onDone
        self.onCancel = onCancel
    }

    // MARK: Body

    public var body: some View {
        NavigationStack {
            Form {
                providerSection
                credentialSection
                if selectedProvider == .custom {
                    serverSection
                }
                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Account")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addAccount() }
                        .disabled(!canAdd)
                }
            }
            .disabled(isAuthenticating)
            .overlay {
                if isAuthenticating {
                    ProgressView("Signing in…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: Sections

    private var providerSection: some View {
        Section("Provider") {
            Picker("Provider", selection: $selectedProvider) {
                ForEach(IMAPProviderType.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedProvider) { _, newProvider in
                // Pre-fill custom host when switching to custom
                if newProvider == .custom && customHost.isEmpty {
                    customHost = ""
                }
                errorMessage = nil
            }
        }
    }

    private var credentialSection: some View {
        Section("Account") {
            TextField("Email address", text: $email)
                .textContentType(.emailAddress)
                #if os(iOS)
                .keyboardType(.emailAddress)
                #endif
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            switch selectedProvider {
            case .gmail, .outlook:
                // OAuth2 — show a sign-in button (wired in Phase 4)
                oauthSignInButton

            case .iCloud, .custom:
                // App-specific password or standard credential
                SecureField(
                    selectedProvider == .iCloud
                        ? "App-specific password"
                        : "Password",
                    text: $password
                )
                .textContentType(.password)
                if selectedProvider == .iCloud {
                    Link("Create app-specific password →",
                         destination: URL(string: "https://appleid.apple.com")!)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var oauthSignInButton: some View {
        Button {
            Task { await startOAuth() }
        } label: {
            Label(
                "Sign in with \(selectedProvider == .gmail ? "Google" : "Microsoft")",
                systemImage: selectedProvider == .gmail ? "envelope.circle" : "building.2"
            )
        }
        .buttonStyle(.borderedProminent)
    }

    private var serverSection: some View {
        Section("Custom Server") {
            TextField("IMAP host (e.g. mail.example.com)", text: $customHost)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
            HStack {
                Text("Port")
                Spacer()
                TextField("993", text: $customPort)
                    .multilineTextAlignment(.trailing)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .frame(width: 60)
            }
        }
    }

    // MARK: Validation

    private var canAdd: Bool {
        let emailOK = email.contains("@") && email.count > 3
        switch selectedProvider {
        case .gmail, .outlook:
            // OAuth: we need a successful sign-in (errorMessage would be nil)
            return emailOK
        case .iCloud, .custom:
            let pwOK = !password.isEmpty
            let hostOK = selectedProvider == .custom ? !customHost.isEmpty : true
            return emailOK && pwOK && hostOK
        }
    }

    // MARK: Actions

    private func addAccount() {
        errorMessage = nil
        let accountId = "\(selectedProvider.rawValue)-\(email)"
        let port = Int(customPort) ?? selectedProvider.defaultPort
        let host = selectedProvider == .custom ? customHost : selectedProvider.defaultHost

        let config = IMAPAccountConfig(
            accountId: accountId,
            displayName: email,
            providerType: selectedProvider,
            host: host,
            port: port,
            username: email
        )

        // Persist credential to Keychain
        do {
            switch selectedProvider {
            case .iCloud, .custom:
                let key = KeychainHelper.passwordKey(accountId: accountId)
                try KeychainHelper.save(password, account: key)
            case .gmail, .outlook:
                // OAuth token already saved during startOAuth()
                break
            }
            onDone(config)
        } catch {
            errorMessage = "Keychain error: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func startOAuth() async {
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        let provider: OAuthProvider = selectedProvider == .gmail ? .google : .microsoft
        do {
            let accountId = "\(selectedProvider.rawValue)-\(email)"
            try await OAuthManager.shared.signIn(provider: provider, accountId: accountId)
            // After successful sign-in, addAccount() can proceed
        } catch OAuthError.userCancelled {
            // Silent — user cancelled
        } catch {
            errorMessage = "Sign-in failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview("Account Setup") {
    AccountSetupView(
        onDone: { config in print("Added:", config.displayName) },
        onCancel: { print("Cancelled") }
    )
}
#endif
