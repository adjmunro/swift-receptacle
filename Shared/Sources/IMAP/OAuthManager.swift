import Foundation
import GoogleSignIn

// MARK: - OAuth Provider

public enum OAuthProvider: String, Sendable {
    case google     // Gmail — GoogleSignIn-iOS SDK
    case microsoft  // Outlook/Exchange — MSAL (Phase 4)
}

// MARK: - OAuthManager

/// Manages OAuth2 tokens for Gmail and Outlook IMAP authentication.
///
/// Tokens are stored in the Keychain via `KeychainHelper` — never in
/// UserDefaults or on disk. An in-memory cache avoids repeated Keychain reads.
///
/// ## Gmail setup (one-time, before first sign-in):
/// 1. Create a project at console.cloud.google.com
/// 2. Enable the Gmail API
/// 3. Create OAuth 2.0 credentials (type: "Desktop app") → get a Client ID
/// 4. In Xcode → ReceptacleApp target → Build Settings → User-Defined, set:
///    `GOOGLE_REVERSED_CLIENT_ID` = `com.googleusercontent.apps.<your-id-suffix>`
///    (i.e. reverse the client ID: `12345-abc.apps.googleusercontent.com`
///     → `com.googleusercontent.apps.12345-abc`)
/// 5. When adding a Gmail account in Settings, enter the Client ID
///    (e.g. `12345-abc.apps.googleusercontent.com`)
///
/// ## Sign-in flow (automatic):
/// ```swift
/// await OAuthManager.shared.configure(googleClientId: "YOUR_CLIENT_ID")
/// let email = try await OAuthManager.shared.signIn(provider: .google, accountId: id)
/// ```
public actor OAuthManager {
    public static let shared = OAuthManager()

    /// In-memory token cache — avoids repeated Keychain reads.
    /// Key: `"<provider>:<accountId>"`
    private var tokenCache: [String: CachedToken] = [:]

    private init() {}

    // MARK: - Configuration

    /// Configure the Google Sign-In SDK with the given client ID.
    ///
    /// Call on app startup if a client ID was previously saved, and again
    /// each time the user enters a new client ID.
    public func configure(googleClientId: String) {
        // Persist so we can restore on next launch
        UserDefaults.standard.set(googleClientId, forKey: "google.oauth.clientId")
        Task { @MainActor in
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: googleClientId)
        }
    }

    // MARK: - Interactive sign-in

    /// Initiates the interactive OAuth2 sign-in flow and returns the signed-in email.
    ///
    /// For Google (macOS): presents `ASWebAuthenticationSession` via the key window.
    /// Stores the access token in Keychain and the in-memory cache.
    ///
    /// - Returns: The email address of the signed-in Google account.
    /// - Throws: `OAuthError.userCancelled` if the user dismisses the browser,
    ///           `OAuthError.noPresentingVC` if there is no key window.
    public func signIn(
        provider: OAuthProvider,
        accountId: String,
        hint: String? = nil
    ) async throws -> String {
        switch provider {

        case .google:
#if os(macOS)
            let result = try await withCheckedThrowingContinuation {
                (cont: CheckedContinuation<(token: String, expiry: Date, email: String), Error>) in
                Task { @MainActor in
                    guard let window = NSApplication.shared.keyWindow
                            ?? NSApplication.shared.windows.first(where: \.isVisible) else {
                        cont.resume(throwing: OAuthError.noPresentingVC)
                        return
                    }
                    GIDSignIn.sharedInstance.signIn(
                        withPresenting: window,
                        hint: hint,
                        additionalScopes: ["https://mail.google.com/"]
                    ) { signInResult, error in
                        if let error {
                            let code = (error as NSError).code
                            // GIDSignInErrorCodeCanceled = -5
                            cont.resume(throwing: code == -5
                                ? OAuthError.userCancelled
                                : OAuthError.tokenRefreshFailed(reason: error.localizedDescription))
                            return
                        }
                        guard let signInResult else {
                            cont.resume(throwing: OAuthError.notAuthenticated)
                            return
                        }
                        cont.resume(returning: (
                            token: signInResult.user.accessToken.tokenString,
                            expiry: signInResult.user.accessToken.expirationDate
                                ?? Date().addingTimeInterval(3600),
                            email: signInResult.user.profile?.email ?? ""
                        ))
                    }
                }
            }
            let cacheKey = "google:\(accountId)"
            tokenCache[cacheKey] = CachedToken(token: result.token, expiresAt: result.expiry)
            try KeychainHelper.save(result.token,
                account: KeychainHelper.oauthTokenKey(accountId: accountId, provider: "google"))
            return result.email
#else
            throw OAuthError.noPresentingVC
#endif

        case .microsoft:
            // MSAL integration — Phase 4
            throw OAuthError.notAuthenticated
        }
    }

    // MARK: - Token retrieval (silent refresh)

    /// Returns a valid Bearer token for IMAP XOAUTH2, refreshing silently if expired.
    public func accessToken(for provider: OAuthProvider, accountId: String) async throws -> String {
        let cacheKey = "\(provider.rawValue):\(accountId)"

        // Return cached token if still valid (>60s margin)
        if let cached = tokenCache[cacheKey], cached.isValid {
            return cached.token
        }

        switch provider {

        case .google:
#if os(macOS)
            let (token, expiry) = try await withCheckedThrowingContinuation {
                (cont: CheckedContinuation<(String, Date), Error>) in
                Task { @MainActor in
                    // Helper — refresh an already-resolved GIDGoogleUser
                    func refresh(_ user: GIDGoogleUser) {
                        user.refreshTokensIfNeeded { refreshed, error in
                            if let error {
                                cont.resume(throwing: OAuthError.tokenRefreshFailed(
                                    reason: error.localizedDescription))
                                return
                            }
                            guard let refreshed else {
                                cont.resume(throwing: OAuthError.notAuthenticated)
                                return
                            }
                            cont.resume(returning: (
                                refreshed.accessToken.tokenString,
                                refreshed.accessToken.expirationDate ?? Date().addingTimeInterval(3600)
                            ))
                        }
                    }

                    if let user = GIDSignIn.sharedInstance.currentUser {
                        refresh(user)
                    } else {
                        // Try to restore from GIDSignIn's Keychain store
                        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                            if let error {
                                cont.resume(throwing: OAuthError.tokenRefreshFailed(
                                    reason: error.localizedDescription))
                                return
                            }
                            guard let user else {
                                cont.resume(throwing: OAuthError.notAuthenticated)
                                return
                            }
                            refresh(user)
                        }
                    }
                }
            }
            tokenCache[cacheKey] = CachedToken(token: token, expiresAt: expiry)
            try KeychainHelper.save(token,
                account: KeychainHelper.oauthTokenKey(accountId: accountId, provider: "google"))
            return token
#else
            throw OAuthError.notAuthenticated
#endif

        case .microsoft:
            throw OAuthError.notAuthenticated
        }
    }

    // MARK: - Sign-out

    /// Signs out of the given provider and clears all cached / Keychain tokens.
    public func signOut(provider: OAuthProvider, accountId: String) throws {
        let cacheKey = "\(provider.rawValue):\(accountId)"
        tokenCache.removeValue(forKey: cacheKey)

        try KeychainHelper.delete(
            account: KeychainHelper.oauthTokenKey(accountId: accountId,
                                                   provider: provider.rawValue))
        try KeychainHelper.delete(
            account: KeychainHelper.oauthRefreshKey(accountId: accountId,
                                                     provider: provider.rawValue))

        switch provider {
        case .google:
            Task { @MainActor in
                GIDSignIn.sharedInstance.signOut()
            }
        case .microsoft:
            break
        }
    }
}

// MARK: - CachedToken

private struct CachedToken: Sendable {
    let token: String
    let expiresAt: Date

    /// True if the token has more than 60 seconds of validity remaining.
    var isValid: Bool { expiresAt.timeIntervalSinceNow > 60 }
}

// MARK: - OAuthError

public enum OAuthError: Error, Sendable {
    case notAuthenticated
    case tokenRefreshFailed(reason: String)
    case userCancelled
    case noPresentingVC
}
