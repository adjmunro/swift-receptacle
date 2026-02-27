import Foundation
import SwiftMail
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

    // MARK: - Connection helpers

    /// Creates and authenticates an IMAPServer connection.
    private func connect() async throws -> IMAPServer {
        let server = IMAPServer(host: config.host, port: config.port)
        try await server.connect()
        let cred = try await credential()
        switch config.authMethod {
        case .password:
            try await server.login(username: config.username, password: cred)
        case .oauth2:
            try await server.authenticateXOAUTH2(email: config.username, accessToken: cred)
        }
        return server
    }

    // MARK: - MessageSource

    func fetchItems(since: Date?) async throws -> [any Item] {
        let server = try await connect()
        defer { Task { try? await server.disconnect() } }

        try await server.selectMailbox("INBOX")

        // Build search criteria: since date if provided, else all messages.
        let criteria: [SearchCriteria] = since.map { [.since($0)] } ?? [.all]
        let uidSet: UIDSet = try await server.search(criteria: criteria)

        guard !uidSet.isEmpty else { return [] }

        var items: [any Item] = []
        for try await msg in server.fetchMessages(using: uidSet) {
            let fromAddr = msg.from ?? ""
            let entityId = entityResolver(fromAddr) ?? "unknown"
            let uid = msg.uid.map { String($0.value) } ?? String(msg.sequenceNumber.value)
            let itemId = "\(config.accountId):INBOX:\(uid)"

            let emailItem = EmailItem(
                id: itemId,
                entityId: entityId,
                sourceId: config.accountId,
                date: msg.date ?? msg.header.internalDate ?? Date(),
                subject: msg.subject ?? "(No subject)",
                fromAddress: fromAddr,
                fromName: nil,
                toAddresses: msg.to,
                ccAddresses: msg.cc,
                replyToAddress: msg.header.additionalFields?["Reply-To"],
                bodyHTML: msg.htmlBody,
                bodyPlain: msg.textBody
            )
            emailItem.isRead = msg.flags.contains(.seen)
            items.append(emailItem)
        }
        return items
    }

    func send(_ reply: Reply) async throws {
        let cred = try await credential()
        let smtpHost = config.providerType.defaultSMTPHost
        guard !smtpHost.isEmpty else { throw MessageSourceError.unsupportedOperation }

        let smtp = SMTPServer(host: smtpHost, port: config.providerType.defaultSMTPPort)
        try await smtp.connect()
        switch config.authMethod {
        case .password:
            try await smtp.login(username: config.username, password: cred)
        case .oauth2:
            try await smtp.authenticateXOAUTH2(email: config.username, accessToken: cred)
        }

        let email = Email(
            sender: EmailAddress(address: config.username),
            recipients: [EmailAddress(address: reply.toAddress)],
            ccRecipients: reply.ccAddresses.map { EmailAddress(address: $0) },
            subject: reply.subject,
            textBody: reply.body,
            additionalHeaders: reply.itemId.isEmpty ? nil : ["In-Reply-To": reply.itemId]
        )
        try await smtp.sendEmail(email)
    }

    func archive(_ item: any Item) async throws {
        guard let uid = uidFromItemId(item.id) else {
            throw MessageSourceError.unsupportedOperation
        }
        let server = try await connect()
        defer { Task { try? await server.disconnect() } }
        try await server.selectMailbox("INBOX")
        try await server.move(message: UID(uid), to: config.effectiveArchiveFolder)
    }

    func delete(_ item: any Item) async throws {
        guard let uid = uidFromItemId(item.id) else {
            throw MessageSourceError.unsupportedOperation
        }
        let server = try await connect()
        defer { Task { try? await server.disconnect() } }
        try await server.selectMailbox("INBOX")
        let set = UIDSet(UID(uid))
        try await server.store(flags: [.deleted], on: set, operation: .add)
        try await server.expunge()
    }

    func markRead(_ item: any Item, read: Bool) async throws {
        guard let uid = uidFromItemId(item.id) else {
            throw MessageSourceError.unsupportedOperation
        }
        let server = try await connect()
        defer { Task { try? await server.disconnect() } }
        try await server.selectMailbox("INBOX")
        let set = UIDSet(UID(uid))
        try await server.store(flags: [.seen], on: set, operation: read ? .add : .remove)
    }

    // MARK: - Private helpers

    /// Extracts the IMAP UID from a composite item ID: "<accountId>:<folder>:<uid>"
    private func uidFromItemId(_ itemId: String) -> UInt32? {
        let parts = itemId.split(separator: ":")
        return parts.last.flatMap { UInt32($0) }
    }
}
