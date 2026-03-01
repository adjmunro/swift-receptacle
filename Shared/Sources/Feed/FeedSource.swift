import Foundation
@preconcurrency import FeedKit
import Receptacle  // FeedConfig, FeedItemRecord, FeedFormat live in ReceptacleCore

// MARK: - FeedSource

/// `MessageSource` adapter for RSS 2.0, Atom 1.0, and JSON Feed 1.1.
///
/// Each feed URL maps to a `Contact` (type: .feed) + `Entity` in SwiftData.
/// The same rules, importance, and retention policies apply as for email entities.
public actor FeedSource: MessageSource {

    public let config: FeedConfig

    public nonisolated var id: String       { config.feedId }
    public nonisolated var sourceId: String { config.feedId }
    public nonisolated var displayName: String { config.displayName }
    public nonisolated var sourceType: SourceType { .rss }

    public init(config: FeedConfig) {
        self.config = config
    }

    // MARK: - MessageSource

    public func fetchItems(since: Date?) async throws -> [any Item] {
        guard let feedURL = URL(string: config.feedURLString) else {
            throw MessageSourceError.invalidConfiguration("Invalid feed URL: \(config.feedURLString)")
        }

        // Fetch data via URLSession (Sendable-safe), then parse synchronously.
        // Avoids passing non-Sendable FeedKit types across concurrency boundaries.
        let (data, _) = try await URLSession.shared.data(from: feedURL)
        let result = FeedParser(data: data).parse()
        let feed: Feed
        switch result {
        case .success(let f): feed = f
        case .failure(let e): throw e as Error
        }

        let records = mapFeed(feed)
        if let cutoff = since {
            return records.filter { $0.date >= cutoff }
        }
        return records
    }

    /// RSS feeds are read-only — replies are not possible.
    public func send(_ reply: Reply) async throws {
        throw MessageSourceError.unsupportedOperation
    }

    /// Archive = mark locally in SwiftData. No server-side state for RSS.
    public func archive(_ item: any Item) async throws {
        // FeedItem state updates are done by the app layer via SwiftData.
        // FeedSource itself is stateless — the caller handles persistence.
    }

    /// Delete = remove from local SwiftData store (handled by app layer).
    public func delete(_ item: any Item) async throws {
        // Deletion of FeedItems is handled by the app layer.
    }

    /// Mark read updates local SwiftData only — no server sync for RSS.
    public func markRead(_ item: any Item, read: Bool) async throws {
        // Read state updates are handled by the app layer via SwiftData.
    }

    // MARK: - Private mapping

    private func mapFeed(_ feed: Feed) -> [FeedItemRecord] {
        switch feed {
        case .rss(let rssFeed):   return mapRSS(rssFeed)
        case .atom(let atomFeed): return mapAtom(atomFeed)
        case .json(let jsonFeed): return mapJSON(jsonFeed)
        }
    }

    private func mapRSS(_ rssFeed: RSSFeed) -> [FeedItemRecord] {
        (rssFeed.items ?? []).compactMap { item -> FeedItemRecord? in
            guard let date = item.pubDate else { return nil }
            let guid = item.guid?.value ?? item.link ?? UUID().uuidString
            let rawHTML = item.content?.contentEncoded ?? item.description
            let html = (rawHTML?.isEmpty == false) ? rawHTML : nil
            return FeedItemRecord(
                id:          FeedItemRecord.makeId(feedId: config.feedId, guid: guid),
                entityId:    config.entityId,
                sourceId:    config.feedId,
                date:        date,
                title:       item.title ?? "(Untitled)",
                summary:     FeedItemRecord.plainSummary(from: html ?? ""),
                linkURL:     item.link,
                contentHTML: html,
                format:      .rss
            )
        }
    }

    private func mapAtom(_ atomFeed: AtomFeed) -> [FeedItemRecord] {
        (atomFeed.entries ?? []).compactMap { entry -> FeedItemRecord? in
            // Prefer `published` (original release date) over `updated` (last-modified).
            // YouTube Atom feeds update <updated> on every comment/like, making all
            // videos appear as "just posted". Using <published> gives the correct date.
            guard let date = entry.published ?? entry.updated else { return nil }
            let link = entry.links?.first(where: { $0.attributes?.rel == "alternate" })?.attributes?.href

            // FeedKit limitation: Atom entries have no parsed path for
            // media:description (including inside media:group). YouTube-style feeds
            // that rely on this field will have nil contentHTML — the inline
            // YouTubePlayerView is the primary content for those items.
            let raw = entry.content?.value ?? entry.summary?.value
            let html: String? = (raw?.isEmpty == false) ? raw : nil

            return FeedItemRecord(
                id:          FeedItemRecord.makeId(feedId: config.feedId,
                                                   guid: entry.id ?? link ?? UUID().uuidString),
                entityId:    config.entityId,
                sourceId:    config.feedId,
                date:        date,
                title:       entry.title ?? "(Untitled)",
                summary:     FeedItemRecord.plainSummary(from: html ?? ""),
                linkURL:     link,
                contentHTML: html,
                format:      .atom
            )
        }
    }

    private func mapJSON(_ jsonFeed: JSONFeed) -> [FeedItemRecord] {
        (jsonFeed.items ?? []).compactMap { item -> FeedItemRecord? in
            guard let date = item.datePublished else { return nil }
            let html = item.contentHtml ?? item.contentText ?? ""
            return FeedItemRecord(
                id:          FeedItemRecord.makeId(feedId: config.feedId,
                                                   guid: item.id ?? UUID().uuidString),
                entityId:    config.entityId,
                sourceId:    config.feedId,
                date:        date,
                title:       item.title ?? "(Untitled)",
                summary:     FeedItemRecord.plainSummary(from: html),
                linkURL:     item.url,
                contentHTML: html,
                format:      .json
            )
        }
    }
}
