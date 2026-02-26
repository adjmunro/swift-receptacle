import Foundation

// MARK: - IMAP Account Configuration

/// All the information needed to connect to an IMAP server.
///
/// Stored securely: auth credentials (password / OAuth token) live in the
/// Keychain — only the non-secret fields are persisted in SwiftData.
public struct IMAPAccountConfig: Sendable, Codable {
    public var accountId: String
    public var displayName: String
    public var host: String
    public var port: Int           // 993 for IMAPS, 143 for STARTTLS
    public var useTLS: Bool        // true → IMAPS; false → STARTTLS
    public var username: String
    public var authMethod: IMAPAuthMethod
    /// Folder name to use for archiving (provider-specific defaults applied if nil)
    public var archiveFolder: String?

    public init(
        accountId: String,
        displayName: String,
        host: String,
        port: Int = 993,
        useTLS: Bool = true,
        username: String,
        authMethod: IMAPAuthMethod,
        archiveFolder: String? = nil
    ) {
        self.accountId = accountId
        self.displayName = displayName
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.username = username
        self.authMethod = authMethod
        self.archiveFolder = archiveFolder
    }

    // MARK: Provider-specific defaults

    /// The folder name to move messages to when archiving.
    public var effectiveArchiveFolder: String {
        if let custom = archiveFolder { return custom }
        // Gmail uses a special All Mail folder
        if host.lowercased().contains("gmail") || host.lowercased().contains("google") {
            return "[Gmail]/All Mail"
        }
        return "Archive"
    }
}

public enum IMAPAuthMethod: String, Sendable, Codable {
    /// App-specific password (iCloud) or standard credentials (custom domain).
    /// Credential fetched from Keychain at connection time.
    case password

    /// OAuth2 Bearer token — token fetched/refreshed via OAuthManager (Phase 4).
    case oauth2
}

// MARK: - IMAPSource

/// `MessageSource` adapter backed by SwiftMail (Cocoanetics/SwiftMail).
///
/// All four IMAP providers use this single adapter — authentication method
/// is the only difference, handled at connection time.
///
/// ## SwiftMail API notes (adjust when Xcode + SwiftMail are set up):
/// SwiftMail uses `IMAPServer` and `SMTPServer` actors. Approximate API shape:
/// ```
/// let server = IMAPServer(hostname: host, port: port)
/// try await server.login(username: username, password: credential)
/// let messages = try await server.messages(in: "INBOX", since: since)
/// try await server.moveMessages(uids: [uid], from: "INBOX", to: archiveFolder)
/// try await server.setFlags([.deleted], forUIDs: [uid], in: "INBOX")
/// try await server.expunge(in: "INBOX")
/// ```
/// The `fetchItems(since:)` implementation maps `SwiftMail.Message` objects
/// to `EmailItem` @Model instances. The entity ID is resolved by matching the
/// From/Reply-To address against the Contact store (app layer responsibility
/// — pass an `entityResolver` closure).
actor IMAPSource: MessageSource {

    let config: IMAPAccountConfig

    nonisolated var id: String      { config.accountId }
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

    /// Returns the credential to use for login.
    /// - Password accounts: fetch from Keychain.
    /// - OAuth2 accounts: delegate to OAuthManager (Phase 4).
    private func credential() async throws -> String {
        switch config.authMethod {
        case .password:
            // Phase 3: KeychainHelper.password(account: config.accountId)
            throw MessageSourceError.notAuthenticated

        case .oauth2:
            // Phase 4: OAuthManager.shared.accessToken(for: provider, accountId: config.accountId)
            throw MessageSourceError.notAuthenticated
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
        //     let item = EmailItem(
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
        //     return item
        // }
        return []
    }

    func send(_ reply: Reply) async throws {
        // Phase 3 — SwiftMail SMTPServer sketch:
        //
        // let cred  = try await credential()
        // let smtp  = SMTPServer(hostname: smtpHost, port: 587)
        // try await smtp.login(username: config.username, password: cred)
        //
        // let message = MailMessage(
        //     from: config.username,
        //     to: [reply.toAddress],
        //     cc: reply.ccAddresses,
        //     subject: "Re: …",   // fetched from original item
        //     body: reply.body,
        //     inReplyTo: reply.itemId
        // )
        // try await smtp.send(message)
        throw MessageSourceError.unsupportedOperation
    }

    func archive(_ item: any Item) async throws {
        // Phase 3:
        // IMAP command: UID MOVE <uid> <archiveFolder>
        //
        // let cred   = try await credential()
        // let server = IMAPServer(hostname: config.host, port: UInt16(config.port))
        // try await server.login(username: config.username, password: cred)
        // let uid    = uidFromItemId(item.id)
        // try await server.moveMessages(uids: [uid], from: "INBOX",
        //                               to: config.effectiveArchiveFolder)
        throw MessageSourceError.unsupportedOperation
    }

    func delete(_ item: any Item) async throws {
        // Phase 3:
        // IMAP commands: UID STORE <uid> +FLAGS (\Deleted)  →  EXPUNGE
        //
        // let cred   = try await credential()
        // let server = IMAPServer(hostname: config.host, port: UInt16(config.port))
        // try await server.login(username: config.username, password: cred)
        // let uid    = uidFromItemId(item.id)
        // try await server.setFlags([.deleted], forUIDs: [uid], in: "INBOX")
        // try await server.expunge(in: "INBOX")
        throw MessageSourceError.unsupportedOperation
    }

    func markRead(_ item: any Item, read: Bool) async throws {
        // Phase 3:
        // IMAP command: UID STORE <uid> +FLAGS (\Seen)  /  -FLAGS (\Seen)
        //
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
