import Foundation
import Receptacle  // IMAPProviderType, IMAPAuthMethod live in ReceptacleCore

// MARK: - IMAP Account Configuration

/// All the information needed to connect to an IMAP server.
///
/// Stored securely: auth credentials (password / OAuth token) live in the
/// Keychain — only the non-secret fields are persisted in SwiftData.
public struct IMAPAccountConfig: Sendable, Codable {
    public var accountId: String
    public var displayName: String
    public var providerType: IMAPProviderType
    public var host: String
    public var port: Int           // 993 for IMAPS, 143 for STARTTLS
    public var useTLS: Bool        // true → IMAPS; false → STARTTLS
    public var username: String
    public var authMethod: IMAPAuthMethod
    /// Override for the archive folder name. Nil → use providerType.defaultArchiveFolder.
    public var archiveFolderOverride: String?

    public init(
        accountId: String,
        displayName: String,
        providerType: IMAPProviderType,
        host: String? = nil,
        port: Int? = nil,
        useTLS: Bool? = nil,
        username: String,
        authMethod: IMAPAuthMethod? = nil,
        archiveFolderOverride: String? = nil
    ) {
        self.accountId = accountId
        self.displayName = displayName
        self.providerType = providerType
        self.host = host ?? providerType.defaultHost
        self.port = port ?? providerType.defaultPort
        self.useTLS = useTLS ?? providerType.defaultUseTLS
        self.username = username
        self.authMethod = authMethod ?? providerType.defaultAuthMethod
        self.archiveFolderOverride = archiveFolderOverride
    }

    // MARK: Provider-specific defaults

    /// The folder name to move messages to when archiving.
    public var effectiveArchiveFolder: String {
        archiveFolderOverride ?? providerType.defaultArchiveFolder
    }
}

// MARK: - IMAPSource

/// `MessageSource` adapter backed by SwiftMail (Cocoanetics/SwiftMail).
///
/// All four IMAP providers use this single adapter — authentication method
/// is the only difference, handled at connection time via `credential()`.
///
/// ## SwiftMail API (wire in Xcode when Phase 4 is complete):
/// ```swift
/// let server = IMAPServer(hostname: config.host, port: UInt16(config.port))
/// try await server.login(username: config.username, password: credential)
/// let messages = try await server.messages(in: "INBOX", since: since)
/// try await server.moveMessages(uids: [uid], from: "INBOX", to: archiveFolder)
/// try await server.setFlags([.deleted], forUIDs: [uid], in: "INBOX")
/// try await server.expunge(in: "INBOX")
/// ```
actor IMAPSource: MessageSource {

    let config: IMAPAccountConfig

    nonisolated var id: String       { config.accountId }
    nonisolated var sourceId: String { config.accountId }
    nonisolated var displayName: String { config.displayName }
    nonisolated var sourceType: SourceType { .email }

    /// Resolves a From address to an entity ID. Injected by the app layer
    /// so this actor has no dependency on SwiftData.
    private let entityResolver: @Sendable (String) -> String?

    init(config: IMAPAccountConfig,
         entityResolver: @escaping @Sendable (String) -> String? = { _ in nil }) {
        self.config = config
        self.entityResolver = entityResolver
    }

    // MARK: - Credential resolution

    /// Returns the credential (password or OAuth Bearer token) for IMAP login.
    ///
    /// - Password accounts: fetched from Keychain via `KeychainHelper`.
    /// - OAuth2 accounts: delegated to `OAuthManager` (silent refresh built-in).
    private func credential() async throws -> String {
        switch config.authMethod {
        case .password:
            let key = KeychainHelper.passwordKey(accountId: config.accountId)
            guard let password = try KeychainHelper.read(account: key) else {
                throw MessageSourceError.notAuthenticated
            }
            return password

        case .oauth2:
            let provider: OAuthProvider = config.providerType == .gmail ? .google : .microsoft
            return try await OAuthManager.shared.accessToken(for: provider,
                                                              accountId: config.accountId)
        }
    }

    // MARK: - MessageSource

    func fetchItems(since: Date?) async throws -> [any Item] {
        // Phase 3 — SwiftMail implementation sketch:
        //
        // let cred = try await credential()
        // let server = IMAPServer(hostname: config.host, port: UInt16(config.port))
        // try await server.login(username: config.username, password: cred)
        //
        // let folder = "INBOX"
        // let messages = try await server.messages(in: folder, since: since)
        //
        // return try messages.map { msg -> EmailItem in
        //     let entityId = entityResolver(msg.from.address) ?? "unknown"
        //     return EmailItem(
        //         id: "\(config.accountId):\(folder):\(msg.uid)",
        //         entityId: entityId,
        //         sourceId: config.accountId,
        //         date: msg.date ?? Date(),
        //         subject: msg.subject ?? "(No subject)",
        //         fromAddress: msg.from.address,
        //         fromName: msg.from.displayName,
        //         toAddresses: msg.to.map(\.address),
        //         ccAddresses: msg.cc.map(\.address),
        //         replyToAddress: msg.replyTo?.address,
        //         bodyHTML: msg.htmlBody,
        //         bodyPlain: msg.plainBody
        //     )
        // }
        return []
    }

    func send(_ reply: Reply) async throws {
        // Phase 4 — SwiftMail SMTPServer sketch:
        //
        // let cred  = try await credential()
        // let smtp  = SMTPServer(hostname: smtpHost, port: 587)
        // try await smtp.login(username: config.username, password: cred)
        //
        // let message = MailMessage(
        //     from: config.username,
        //     to: [reply.toAddress],
        //     cc: reply.ccAddresses,
        //     subject: "Re: …",  // fetched from original item
        //     body: reply.body,
        //     inReplyTo: reply.itemId
        // )
        // try await smtp.send(message)
        throw MessageSourceError.unsupportedOperation
    }

    func archive(_ item: any Item) async throws {
        // Phase 4:
        // let cred   = try await credential()
        // let server = IMAPServer(hostname: config.host, port: UInt16(config.port))
        // try await server.login(username: config.username, password: cred)
        // let uid    = uidFromItemId(item.id)
        // try await server.moveMessages(uids: [uid], from: "INBOX",
        //                               to: config.effectiveArchiveFolder)
        throw MessageSourceError.unsupportedOperation
    }

    func delete(_ item: any Item) async throws {
        // Phase 4:
        // let cred   = try await credential()
        // let server = IMAPServer(hostname: config.host, port: UInt16(config.port))
        // try await server.login(username: config.username, password: cred)
        // let uid    = uidFromItemId(item.id)
        // try await server.setFlags([.deleted], forUIDs: [uid], in: "INBOX")
        // try await server.expunge(in: "INBOX")
        throw MessageSourceError.unsupportedOperation
    }

    func markRead(_ item: any Item, read: Bool) async throws {
        // Phase 4:
        // let cred   = try await credential()
        // let server = IMAPServer(hostname: config.host, port: UInt16(config.port))
        // try await server.login(username: config.username, password: cred)
        // let uid    = uidFromItemId(item.id)
        // let flag   = IMAPFlag.seen
        // if read {
        //     try await server.setFlags([flag], forUIDs: [uid], in: "INBOX")
        // } else {
        //     try await server.clearFlags([flag], forUIDs: [uid], in: "INBOX")
        // }
        throw MessageSourceError.unsupportedOperation
    }

    // MARK: - Private helpers

    /// Extracts the IMAP UID from a composite item ID: "<accountId>:<folder>:<uid>"
    private func uidFromItemId(_ itemId: String) -> UInt32 {
        let parts = itemId.split(separator: ":")
        return parts.last.flatMap { UInt32($0) } ?? 0
    }
}
