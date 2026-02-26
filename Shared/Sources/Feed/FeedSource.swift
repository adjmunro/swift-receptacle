import Foundation
import Receptacle  // FeedConfig, FeedItemRecord, FeedFormat live in ReceptacleCore

// MARK: - FeedSource

/// `MessageSource` adapter for RSS 2.0, Atom 1.0, and JSON Feed 1.1.
///
/// Each feed URL maps to a `Contact` (type: .feed) + `Entity` in SwiftData.
/// The same rules, importance, and retention policies apply as for email entities.
///
/// ## FeedKit integration (requires Xcode — wired in Phase 5):
///
/// ### RSS 2.0:
/// ```swift
/// let parser = FeedParser(URL: feedURL)
/// let result = await withCheckedThrowingContinuation { cont in
///     parser.parseAsync(queue: .global()) { result in
///         cont.resume(with: result.mapError { $0 })
///     }
/// }
/// if case .rss(let rssFeed) = result {
///     let items = rssFeed.items ?? []
///     return items.compactMap { rssItem -> FeedItemRecord? in
///         guard let date = rssItem.pubDate else { return nil }
///         let guid = rssItem.guid?.value ?? rssItem.link ?? UUID().uuidString
///         let html = rssItem.content?.contentEncoded ?? rssItem.description ?? ""
///         return FeedItemRecord(
///             id:          FeedItemRecord.makeId(feedId: config.feedId, guid: guid),
///             entityId:    config.entityId,
///             sourceId:    config.feedId,
///             date:        date,
///             title:       rssItem.title ?? "(Untitled)",
///             summary:     FeedItemRecord.plainSummary(from: html),
///             linkURL:     rssItem.link,
///             contentHTML: html,
///             format:      .rss
///         )
///     }
/// }
/// ```
///
/// ### Atom 1.0:
/// ```swift
/// if case .atom(let atomFeed) = result {
///     let entries = atomFeed.entries ?? []
///     return entries.compactMap { entry -> FeedItemRecord? in
///         guard let date = entry.updated ?? entry.published else { return nil }
///         let link = entry.links?.first(where: { $0.attributes?.rel == "alternate" })
///                           ?.attributes?.href
///         let html = entry.content?.value ?? entry.summary?.value ?? ""
///         return FeedItemRecord(
///             id:          FeedItemRecord.makeId(feedId: config.feedId,
///                                                guid: entry.id ?? link ?? UUID().uuidString),
///             entityId:    config.entityId,
///             sourceId:    config.feedId,
///             date:        date,
///             title:       entry.title?.value ?? "(Untitled)",
///             summary:     FeedItemRecord.plainSummary(from: html),
///             linkURL:     link,
///             contentHTML: html,
///             format:      .atom
///         )
///     }
/// }
/// ```
///
/// ### JSON Feed 1.1:
/// ```swift
/// if case .json(let jsonFeed) = result {
///     let items = jsonFeed.items ?? []
///     return items.compactMap { item -> FeedItemRecord? in
///         guard let date = item.datePublished else { return nil }
///         let html = item.contentHTML ?? item.contentText ?? ""
///         return FeedItemRecord(
///             id:          FeedItemRecord.makeId(feedId: config.feedId,
///                                                guid: item.id ?? UUID().uuidString),
///             entityId:    config.entityId,
///             sourceId:    config.feedId,
///             date:        date,
///             title:       item.title ?? "(Untitled)",
///             summary:     FeedItemRecord.plainSummary(from: html),
///             linkURL:     item.url,
///             contentHTML: html,
///             format:      .json
///         )
///     }
/// }
/// ```
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

        // Phase 5 — FeedKit integration (uncomment when FeedKit is linked in Xcode):
        //
        // let parser = FeedParser(URL: feedURL)
        // let feed: Feed = try await withCheckedThrowingContinuation { cont in
        //     parser.parseAsync(queue: .global(qos: .userInitiated)) { result in
        //         cont.resume(with: result.mapError { $0 as Error })
        //     }
        // }
        // let records = try mapFeed(feed)
        // return since.map { cutoff in records.filter { $0.date >= cutoff } } ?? records

        _ = feedURL  // suppress unused warning until FeedKit is wired
        return []
    }

    /// RSS feeds are read-only — replies are not possible.
    public func send(_ reply: Reply) async throws {
        throw MessageSourceError.unsupportedOperation
    }

    /// Archive = dismiss locally (mark not-shown in SwiftData).
    /// No server-side state to update.
    public func archive(_ item: any Item) async throws {
        // Phase 5: update FeedItem.isArchived = true in SwiftData via a callback/actor
        throw MessageSourceError.unsupportedOperation
    }

    /// Delete = remove from local SwiftData store.
    public func delete(_ item: any Item) async throws {
        // Phase 5: modelContext.delete(feedItem)
        throw MessageSourceError.unsupportedOperation
    }

    /// Mark read updates local SwiftData only — no server sync for RSS.
    public func markRead(_ item: any Item, read: Bool) async throws {
        // Phase 5: feedItem.isRead = read via modelContext
        throw MessageSourceError.unsupportedOperation
    }

    // MARK: - Private mapping

    // private func mapFeed(_ feed: Feed) throws -> [FeedItemRecord] {
    //     switch feed {
    //     case .rss(let rssFeed):   return mapRSS(rssFeed)
    //     case .atom(let atomFeed): return mapAtom(atomFeed)
    //     case .json(let jsonFeed): return mapJSON(jsonFeed)
    //     }
    // }
    //
    // private func mapRSS(_ rssFeed: RSSFeed) -> [FeedItemRecord] { ... }
    // private func mapAtom(_ atomFeed: AtomFeed) -> [FeedItemRecord] { ... }
    // private func mapJSON(_ jsonFeed: JSONFeed) -> [FeedItemRecord] { ... }
}
