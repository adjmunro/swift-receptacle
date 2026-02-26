import Foundation

// MARK: - MockItem

/// A minimal `Item` value type for use in tests and `ReceptacleVerify`.
public struct MockItem: Item, Sendable {
    public var id: String
    public var entityId: String
    public var sourceId: String
    public var date: Date
    public var summary: String

    public init(
        id: String,
        entityId: String,
        sourceId: String = "mock-source",
        date: Date = Date(),
        summary: String = ""
    ) {
        self.id = id
        self.entityId = entityId
        self.sourceId = sourceId
        self.date = date
        self.summary = summary
    }
}

// MARK: - MockMessageSource

/// A fully in-memory `MessageSource` for unit tests and `ReceptacleVerify`.
///
/// Tracks every mutation so tests can assert exact call behaviour without
/// requiring a real IMAP connection or network.
///
/// Usage:
/// ```swift
/// let source = MockMessageSource()
/// await source.addItem(MockItem(id: "m1", entityId: "e1", date: .now))
///
/// let items = try await source.fetchItems(since: nil)
/// try await source.archive(items[0])
/// assert(await source.archivedIds.contains("m1"))
/// ```
public actor MockMessageSource: MessageSource {

    // MessageSource identity (nonisolated so callers can read without await)
    public nonisolated let id: String
    public nonisolated let sourceId: String
    public nonisolated let displayName: String
    public nonisolated let sourceType: SourceType

    // Internal state
    private var items: [MockItem] = []

    // Observable call-tracking (read with `await source.archivedIds`)
    public private(set) var archivedIds: Set<String> = []
    public private(set) var deletedIds:  Set<String> = []
    public private(set) var readIds:     Set<String> = []
    public private(set) var sentReplies: [Reply]     = []

    // MARK: Init

    public init(
        id: String = UUID().uuidString,
        sourceId: String? = nil,
        displayName: String = "Mock Source",
        sourceType: SourceType = .email,
        items: [MockItem] = []
    ) {
        self.id = id
        self.sourceId = sourceId ?? id
        self.displayName = displayName
        self.sourceType = sourceType
        self.items = items
    }

    // MARK: Test-setup helpers

    /// Appends an item to the source (simulates a new message arriving).
    public func addItem(_ item: MockItem) {
        items.append(item)
    }

    /// Replaces all items (convenience for bulk test setup).
    public func setItems(_ newItems: [MockItem]) {
        items = newItems
    }

    // MARK: MessageSource

    public func fetchItems(since: Date?) async throws -> [any Item] {
        items.filter { item in
            guard !archivedIds.contains(item.id) else { return false }
            guard !deletedIds.contains(item.id)  else { return false }
            guard let since else { return true }
            return item.date >= since
        }
    }

    public func send(_ reply: Reply) async throws {
        sentReplies.append(reply)
    }

    public func archive(_ item: any Item) async throws {
        archivedIds.insert(item.id)
    }

    public func delete(_ item: any Item) async throws {
        deletedIds.insert(item.id)
    }

    public func markRead(_ item: any Item, read: Bool) async throws {
        if read {
            readIds.insert(item.id)
        } else {
            readIds.remove(item.id)
        }
    }
}
