import Foundation

// MARK: - Item Protocol

/// Base type for all items from any source.
///
/// Email messages, RSS articles, IM messages, and calendar events all conform.
/// All concrete types are stored in SwiftData.
protocol Item: Identifiable, Sendable {
    var id: String { get }
    /// ID of the `Entity` this item belongs to
    var entityId: String { get }
    /// ID of the `MessageSource` that produced this item
    var sourceId: String { get }
    var date: Date { get }
    /// Plain-text preview for the list row (≤150 chars)
    var summary: String { get }
}

// MARK: - Reply

/// A composed reply to an item.
struct Reply: Sendable {
    var itemId: String
    var body: String
    /// Effective reply-to address (caller resolves Reply-To / From precedence)
    var toAddress: String
    var ccAddresses: [String]

    init(itemId: String, body: String, toAddress: String, ccAddresses: [String] = []) {
        self.itemId = itemId
        self.body = body
        self.toAddress = toAddress
        self.ccAddresses = ccAddresses
    }
}

// MARK: - MessageSource Protocol

/// Everything that can produce or receive items.
///
/// IMAP, RSS, and future IM adapters all implement this protocol.
/// Adding a new integration = one new `MessageSource` conformance.
protocol MessageSource: Identifiable, Sendable {
    var sourceId: String { get }
    var displayName: String { get }
    var sourceType: SourceType { get }

    /// Fetch new items since the given date (nil = full initial sync)
    func fetchItems(since: Date?) async throws -> [any Item]
    /// Send a composed reply
    func send(_ reply: Reply) async throws
    /// Archive an item (server-side, reflected across devices)
    func archive(_ item: any Item) async throws
    /// Delete an item (server-side)
    func delete(_ item: any Item) async throws
    /// Mark item as read/unread
    func markRead(_ item: any Item, read: Bool) async throws
}

// MARK: - MessageSourceError

enum MessageSourceError: Error, Sendable {
    case notAuthenticated
    case networkUnavailable
    case itemNotFound(id: String)
    case sendFailed(reason: String)
    case unsupportedOperation
}
