import Foundation

// MARK: - OAuth Provider

public enum OAuthProvider: String, Sendable {
    case google     // Gmail — GoogleSignIn-iOS SDK
    case microsoft  // Outlook/Exchange — MSAL
}

// MARK: - OAuthManager

/// Manages OAuth2 tokens for Gmail and Outlook IMAP authentication.
///
/// Tokens are stored in the Keychain via `KeychainHelper` — never in
/// UserDefaults or on disk.
///
/// ## GoogleSignIn-iOS integration (Phase 4 — requires Xcode):
/// ```swift
/// // In your App/@UIApplicationDelegateAdaptor, call:
/// GIDSignIn.sharedInstance.handle(openURL)
///
/// // To sign in:
/// let result = try await GIDSignIn.sharedInstance.signIn(
///     withPresenting: rootViewController,
///     hint: username,
///     additionalScopes: ["https://mail.google.com/"]
/// )
/// // result.user.accessToken.tokenString → Bearer token for IMAP XOAUTH2
/// // Cache in Keychain: KeychainHelper.save(token, account: key)
///
/// // To refresh silently:
/// let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
/// let refreshed = try await user.refreshTokensIfNeeded()
/// // refreshed.accessToken.tokenString → refreshed Bearer token
/// ```
///
/// ## MSAL integration (Phase 4 — requires Xcode):
/// ```swift
/// let config = MSALPublicClientApplicationConfig(
///     clientId: "<your-azure-client-id>",
///     redirectUri: "msauth.<bundle-id>://auth",
///     authority: try MSALAADAuthority(url: URL(string:
///         "https://login.microsoftonline.com/common")!)
/// )
/// let app = try MSALPublicClientApplication(configuration: config)
///
/// // Interactive sign-in:
/// let params = MSALInteractiveTokenParameters(
///     scopes: ["https://outlook.office.com/IMAP.AccessAsUser.All",
///              "offline_access"],
///     webviewParameters: MSALWebviewParameters(authPresentationViewController: vc)
/// )
/// let result = try await app.acquireToken(with: params)
/// // result.accessToken → Bearer token for IMAP XOAUTH2
///
/// // Silent refresh:
/// let silentParams = MSALSilentTokenParameters(
///     scopes: params.scopes,
///     account: savedAccount
/// )
/// let refreshed = try await app.acquireTokenSilent(with: silentParams)
/// ```
public actor OAuthManager {
    public static let shared = OAuthManager()

    // Cache of valid access tokens (accountId → token)
    // Persisted to Keychain; in-memory cache avoids repeated Keychain reads.
    private var tokenCache: [String: CachedToken] = [:]

    private init() {}

    // MARK: - Token retrieval

    /// Returns a valid Bearer token for IMAP XOAUTH2, refreshing silently if needed.
    ///
    /// Throws `OAuthError.notAuthenticated` until Phase 4 GoogleSignIn/MSAL
    /// SDK integration is wired in Xcode.
    public func accessToken(for provider: OAuthProvider,
                            accountId: String) async throws -> String {
        let cacheKey = "\(provider.rawValue):\(accountId)"

        // Return cached token if still valid (>60s margin)
        if let cached = tokenCache[cacheKey], cached.isValid {
            return cached.token
        }

        switch provider {
        case .google:
            // Phase 4 implementation — uncomment when GoogleSignIn-iOS is linked:
            //
            // let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            // let refreshed = try await user.refreshTokensIfNeeded()
            // let token = refreshed.accessToken.tokenString
            // let expiry = refreshed.accessToken.expirationDate ?? Date().addingTimeInterval(3600)
            // tokenCache[cacheKey] = CachedToken(token: token, expiresAt: expiry)
            // try KeychainHelper.save(token,
            //     account: KeychainHelper.oauthTokenKey(accountId: accountId, provider: "google"))
            // return token
            throw OAuthError.notAuthenticated

        case .microsoft:
            // Phase 4 implementation — uncomment when MSAL is linked:
            //
            // let app = try msalApp()
            // guard let account = try app.allAccounts().first(where: { $0.identifier == accountId }) else {
            //     throw OAuthError.notAuthenticated
            // }
            // let params = MSALSilentTokenParameters(
            //     scopes: ["https://outlook.office.com/IMAP.AccessAsUser.All", "offline_access"],
            //     account: account
            // )
            // let result = try await app.acquireTokenSilent(with: params)
            // let expiry = result.expiresOn ?? Date().addingTimeInterval(3600)
            // tokenCache[cacheKey] = CachedToken(token: result.accessToken, expiresAt: expiry)
            // try KeychainHelper.save(result.accessToken,
            //     account: KeychainHelper.oauthTokenKey(accountId: accountId, provider: "microsoft"))
            // return result.accessToken
            throw OAuthError.notAuthenticated
        }
    }

    // MARK: - Sign-in (interactive, must be called from MainActor)

    /// Initiates the interactive sign-in flow.
    ///
    /// Must be called from the main actor (presents a web sheet).
    @MainActor
    public func signIn(provider: OAuthProvider,
                       accountId: String) async throws {
        switch provider {
        case .google:
            // Phase 4:
            // guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            //       let vc = scene.windows.first?.rootViewController else { throw OAuthError.noPresentingVC }
            // let result = try await GIDSignIn.sharedInstance.signIn(
            //     withPresenting: vc,
            //     additionalScopes: ["https://mail.google.com/"]
            // )
            // store result in tokenCache + Keychain
            throw OAuthError.notAuthenticated

        case .microsoft:
            // Phase 4:
            // let app = try msalApp()
            // let params = MSALInteractiveTokenParameters(
            //     scopes: ["https://outlook.office.com/IMAP.AccessAsUser.All", "offline_access"],
            //     webviewParameters: ...
            // )
            // let result = try await app.acquireToken(with: params)
            // store result in tokenCache + Keychain
            throw OAuthError.notAuthenticated
        }
    }

    // MARK: - Sign-out

    public func signOut(provider: OAuthProvider, accountId: String) throws {
        let cacheKey = "\(provider.rawValue):\(accountId)"
        tokenCache.removeValue(forKey: cacheKey)

        // Clear both access and refresh tokens from Keychain
        try KeychainHelper.delete(
            account: KeychainHelper.oauthTokenKey(accountId: accountId,
                                                   provider: provider.rawValue))
        try KeychainHelper.delete(
            account: KeychainHelper.oauthRefreshKey(accountId: accountId,
                                                     provider: provider.rawValue))

        // Phase 4: also call SDK sign-out
        // switch provider {
        // case .google:
        //     GIDSignIn.sharedInstance.signOut()
        // case .microsoft:
        //     let app = try msalApp()
        //     try app.allAccounts().forEach { try app.remove($0) }
        // }
    }

    // MARK: - Private helpers

    // private func msalApp() throws -> MSALPublicClientApplication {
    //     let config = MSALPublicClientApplicationConfig(
    //         clientId: "<your-azure-client-id>",
    //         redirectUri: "msauth.\(Bundle.main.bundleIdentifier ?? "")://auth",
    //         authority: try MSALAADAuthority(url: URL(string: "https://login.microsoftonline.com/common")!)
    //     )
    //     return try MSALPublicClientApplication(configuration: config)
    // }
}

// MARK: - CachedToken

private struct CachedToken: Sendable {
    let token: String
    let expiresAt: Date

    /// True if the token has more than 60 seconds of validity remaining.
    var isValid: Bool {
        expiresAt.timeIntervalSinceNow > 60
    }
}

// MARK: - OAuthError

public enum OAuthError: Error, Sendable {
    case notAuthenticated
    case tokenRefreshFailed(reason: String)
    case userCancelled
    case noPresentingVC
}
