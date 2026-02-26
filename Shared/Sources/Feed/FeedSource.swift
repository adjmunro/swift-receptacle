import Foundation

// MARK: - Feed Account Configuration

struct FeedConfig: Sendable {
    var feedId: String
    var displayName: String
    var feedURLString: String
    var entityId: String
}

// MARK: - FeedSource

/// MessageSource adapter for RSS 2.0, Atom, and JSON Feed.
///
/// Each feed URL maps to a `Contact` + `Entity` — same rules, importance,
/// and retention policies apply as for email entities.
/// Phase 5 implementation: integrate FeedKit.
actor FeedSource: MessageSource {
    let config: FeedConfig

    var id: String { config.feedId }
    var sourceId: String { config.feedId }
    var displayName: String { config.displayName }
    var sourceType: SourceType { .rss }

    init(config: FeedConfig) {
        self.config = config
    }

    func fetchItems(since: Date?) async throws -> [any Item] {
        // TODO Phase 5:
        // let feedURL = URL(string: config.feedURLString)!
        // let parser = FeedParser(URL: feedURL)
        // let result = await parser.parseAsync()
        // switch result {
        // case .success(let feed):
        //     let entries = feed.rssFeed?.items ?? feed.atomFeed?.entries ?? []
        //     return entries.compactMap { FeedItem(from: $0, feedConfig: config) }
        // case .failure(let error):
        //     throw error
        // }
        return []
    }

    func send(_ reply: Reply) async throws {
        // RSS feeds are read-only — no reply possible
        throw MessageSourceError.unsupportedOperation
    }

    func archive(_ item: any Item) async throws {
        // Archive = mark as read locally; no server-side state
        throw MessageSourceError.unsupportedOperation
    }

    func delete(_ item: any Item) async throws {
        // Delete = remove from local SwiftData store
        throw MessageSourceError.unsupportedOperation
    }

    func markRead(_ item: any Item, read: Bool) async throws {
        // TODO Phase 5: update FeedItem.isRead in SwiftData
        throw MessageSourceError.unsupportedOperation
    }
}
