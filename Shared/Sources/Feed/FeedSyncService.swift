import Foundation
import SwiftData
import Receptacle

// MARK: - FeedSyncService

/// Fetches remote feed content and persists new `FeedItem` rows into SwiftData.
///
/// All methods run on the `@MainActor` so that `ModelContext` access stays on
/// the main thread (SwiftData requirement). HTTP work happens inside `FeedSource`
/// (an actor on its own executor), so the main actor is freed during network I/O.
@MainActor
enum FeedSyncService {

    /// Tracks the last successful sync time per feed ID (in-memory; resets on launch).
    /// Used to honour each feed's `feedRefreshIntervalMinutes` setting during the
    /// session so navigating back to the sidebar doesn't trigger redundant fetches.
    private static var lastSyncTimes: [String: Date] = [:]

    // MARK: - Full refresh

    /// Sync every feed contact found in the store.
    ///
    /// 1. Fetches all `Contact` rows, filters for `.feed` type in Swift
    ///    (avoids `#Predicate` enum-comparison issues).
    /// 2. Matches each feed contact to its `Entity` via `contactIds`.
    /// 3. Skips feeds whose last sync is within their configured refresh interval.
    /// 4. Calls `syncFeed(config:context:)` for each eligible feed sequentially.
    ///    The main actor suspends during each network fetch, so the UI stays
    ///    responsive even though calls appear sequential.
    static func sync(context: ModelContext) async {
        let allContacts = (try? context.fetch(FetchDescriptor<Contact>())) ?? []
        let feedContacts = allContacts.filter { $0.type == .feed }

        let allEntities = (try? context.fetch(FetchDescriptor<Entity>())) ?? []

        for contact in feedContacts {
            guard
                let urlStr = contact.sourceIdentifiers
                    .first(where: { $0.type == .rss })?.value,
                let entity = allEntities
                    .first(where: { $0.contactIds.contains(contact.id.uuidString) })
            else { continue }

            // Rate-limit: skip if we synced this feed within its refresh interval.
            let feedId = contact.id.uuidString
            let intervalSeconds = TimeInterval(entity.feedRefreshIntervalMinutes * 60)
            if let last = lastSyncTimes[feedId],
               Date().timeIntervalSince(last) < intervalSeconds { continue }

            let config = FeedConfig(
                feedId: feedId,
                displayName: contact.displayName,
                feedURLString: urlStr,
                entityId: entity.id.uuidString
            )
            await syncFeed(config: config, context: context)
        }
    }

    // MARK: - Single feed

    /// Fetch one feed and insert any new items into SwiftData.
    ///
    /// Deduplication is done by checking the composite `FeedItem.id`
    /// (feedId + article GUID) against all existing rows for this source.
    static func syncFeed(config: FeedConfig, context: ModelContext) async {
        // Determine the most-recent stored item to use as a `since` cutoff.
        var sinceDesc = FetchDescriptor<FeedItem>(
            predicate: #Predicate { $0.sourceId == config.feedId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        sinceDesc.fetchLimit = 1
        let since: Date? = (try? context.fetch(sinceDesc))?.first?.date

        await fetchAndInsert(config: config, since: since, context: context)
        applyRetention(for: config, context: context)
        lastSyncTimes[config.feedId] = Date()
    }

    /// Fetch ignoring the `since` cutoff — retrieves all items the feed currently
    /// exposes, inserting any that aren't already cached. Use for manual "Sync Now".
    static func syncFeedForced(config: FeedConfig, context: ModelContext) async {
        await fetchAndInsert(config: config, since: nil, context: context)
        applyRetention(for: config, context: context)
    }

    /// Delete every cached item for this feed, then do a full forced fetch.
    /// Use for "Clear Cache & Sync" when the local data is stale or corrupt.
    static func clearAndSyncFeed(config: FeedConfig, context: ModelContext) async {
        let deleteDesc = FetchDescriptor<FeedItem>(
            predicate: #Predicate { $0.sourceId == config.feedId }
        )
        (try? context.fetch(deleteDesc))?.forEach { context.delete($0) }
        try? context.save()
        await syncFeedForced(config: config, context: context)
    }

    // MARK: - Private

    /// Apply the entity's retention policy to all active (non-saved) items for one feed.
    ///
    /// Called after every insert so the store never grows beyond the configured limit.
    /// Items are evaluated newest-first so `keepLatest(n)` rank 0 == newest, matching
    /// the contract documented in `RuleEngine.evaluate(items:entity:)`.
    private static func applyRetention(for config: FeedConfig, context: ModelContext) {
        // 1. Locate the owning entity.
        let allEntities = (try? context.fetch(FetchDescriptor<Entity>())) ?? []
        guard let entity = allEntities.first(where: { $0.id.uuidString == config.entityId })
        else { return }

        // 2. Fetch active (non-saved) items for this feed, newest-first.
        let itemsDesc = FetchDescriptor<FeedItem>(
            predicate: #Predicate { $0.sourceId == config.feedId && !$0.isSaved },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let feedItems = (try? context.fetch(itemsDesc)) ?? []
        guard !feedItems.isEmpty else { return }

        // 3. Convert to value-type snapshots (RuleEngine is decoupled from SwiftData).
        let snapshots = feedItems.map {
            ItemSnapshot(id: $0.id, entityId: $0.entityId, date: $0.date, subject: $0.title)
        }
        let entitySnapshot = EntitySnapshot(
            id: entity.id.uuidString,
            retentionPolicy: entity.retentionPolicy,
            protectionLevel: entity.protectionLevel,
            importanceLevel: entity.importanceLevel,
            importancePatterns: entity.importancePatterns,
            subRules: entity.subRules
        )

        // 4. Evaluate — pure business logic, no side effects.
        let result = RuleEngine().evaluate(items: snapshots, entity: entitySnapshot)
        guard !result.itemsToDelete.isEmpty || !result.itemsToArchive.isEmpty else { return }

        // 5. Apply deletions and archives.
        let toDeleteIds  = Set(result.itemsToDelete)
        let toArchiveIds = Set(result.itemsToArchive)
        for item in feedItems {
            if toDeleteIds.contains(item.id) {
                context.delete(item)
            } else if toArchiveIds.contains(item.id) {
                item.isSaved = true
            }
        }
        try? context.save()
    }

    private static func fetchAndInsert(
        config: FeedConfig,
        since: Date?,
        context: ModelContext
    ) async {
        let existingDesc = FetchDescriptor<FeedItem>(
            predicate: #Predicate { $0.sourceId == config.feedId }
        )
        let existingIds = Set((try? context.fetch(existingDesc))?.map(\.id) ?? [])

        let source = FeedSource(config: config)
        guard let items = try? await source.fetchItems(since: since) else { return }

        for item in items {
            guard let record = item as? FeedItemRecord,
                  !existingIds.contains(record.id) else { continue }

            let feedItem = FeedItem(
                id: record.id,
                entityId: record.entityId,
                sourceId: record.sourceId,
                date: record.date,
                title: record.title,
                feedFormat: record.format,
                contentHTML: record.contentHTML,
                linkURLString: record.linkURL
            )
            context.insert(feedItem)
        }

        try? context.save()
    }
}
