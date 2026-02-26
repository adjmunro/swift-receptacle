import Foundation

// MARK: - OAuth Provider

enum OAuthProvider: String, Sendable {
    case google     // Gmail — GoogleSignIn SDK
    case microsoft  // Outlook/Exchange — MSAL
}

// MARK: - OAuthManager

/// Manages OAuth2 tokens for Gmail and Outlook IMAP authentication.
///
/// Tokens are stored in the Keychain (never in UserDefaults or on disk).
/// Phase 4 implementation: integrate GoogleSignIn-iOS and MSAL.
actor OAuthManager {
    static let shared = OAuthManager()

    private init() {}

    /// Returns a valid Bearer token, refreshing silently if needed.
    func accessToken(for provider: OAuthProvider, accountId: String) async throws -> String {
        // TODO Phase 4:
        // switch provider {
        // case .google:
        //     let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
        //     return try await user.refreshTokensIfNeeded().accessToken.tokenString
        // case .microsoft:
        //     let result = try await MSALPublicClientApplication(...)
        //         .acquireTokenSilent(with: parameters)
        //     return result.accessToken
        // }
        throw OAuthError.notAuthenticated
    }

    /// Initiates the sign-in flow. Must be called from the main actor.
    @MainActor
    func signIn(provider: OAuthProvider) async throws {
        // TODO Phase 4
        throw OAuthError.notAuthenticated
    }

    func signOut(provider: OAuthProvider, accountId: String) async throws {
        // TODO Phase 4: revoke token + clear Keychain entry
    }
}

enum OAuthError: Error, Sendable {
    case notAuthenticated
    case tokenRefreshFailed(reason: String)
    case userCancelled
}
