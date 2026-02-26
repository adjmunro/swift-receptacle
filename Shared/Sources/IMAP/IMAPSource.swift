import Foundation

// MARK: - IMAP Account Configuration

struct IMAPAccountConfig: Sendable {
    var accountId: String
    var displayName: String
    var host: String
    var port: Int
    var useTLS: Bool
    var username: String
    var authMethod: IMAPAuthMethod
}

enum IMAPAuthMethod: Sendable {
    case password   // iCloud app-specific password, custom domain
    case oauth2     // Gmail, Outlook — token managed by OAuthManager
}

// MARK: - IMAPSource

/// MessageSource adapter backed by SwiftMail.
///
/// Phase 3 implementation: connects to any IMAP server using the configured auth method.
/// All four providers (Gmail, iCloud, Outlook, custom domain) use this single adapter.
actor IMAPSource: MessageSource {
    let config: IMAPAccountConfig

    var id: String { config.accountId }
    var sourceId: String { config.accountId }
    var displayName: String { config.displayName }
    var sourceType: SourceType { .email }

    init(config: IMAPAccountConfig) {
        self.config = config
    }

    func fetchItems(since: Date?) async throws -> [any Item] {
        // TODO Phase 3: connect via SwiftMail IMAPServer actor
        // let server = IMAPServer(host: config.host, port: config.port, ...)
        // let messages = try await server.fetchMessages(since: since)
        // return messages.map { EmailItem(from: $0, sourceId: sourceId, entityId: ...) }
        return []
    }

    func send(_ reply: Reply) async throws {
        // TODO Phase 3: use SwiftMail SMTPServer actor
        throw MessageSourceError.unsupportedOperation
    }

    func archive(_ item: any Item) async throws {
        // TODO Phase 3: IMAP MOVE to [Gmail]/All Mail or Archive folder
        throw MessageSourceError.unsupportedOperation
    }

    func delete(_ item: any Item) async throws {
        // TODO Phase 3: IMAP STORE +FLAGS (\Deleted) + EXPUNGE
        throw MessageSourceError.unsupportedOperation
    }

    func markRead(_ item: any Item, read: Bool) async throws {
        // TODO Phase 3: IMAP STORE +/-FLAGS (\Seen)
        throw MessageSourceError.unsupportedOperation
    }
}
