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

    // MARK: - Full refresh

    /// Sync every feed contact found in the store.
    ///
    /// 1. Fetches all `Contact` rows, filters for `.feed` type in Swift
    ///    (avoids `#Predicate` enum-comparison issues).
    /// 2. Matches each feed contact to its `Entity` via `contactIds`.
    /// 3. Calls `syncFeed(config:context:)` for each feed sequentially.
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

            let config = FeedConfig(
                feedId: contact.id.uuidString,
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

        // Collect existing IDs to skip duplicates.
        let existingDesc = FetchDescriptor<FeedItem>(
            predicate: #Predicate { $0.sourceId == config.feedId }
        )
        let existingIds = Set((try? context.fetch(existingDesc))?.map(\.id) ?? [])

        // Fetch from remote (suspends on main, runs inside FeedSource actor).
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
                contentHTML: record.contentHTML,
                linkURLString: record.linkURL
            )
            context.insert(feedItem)
        }

        try? context.save()
    }
}
