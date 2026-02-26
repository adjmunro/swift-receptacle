// ReceptacleTests/IMAPSourceTests.swift
//
// IMPORTANT: Excluded from Package.swift CLI build (same _Testing_Foundation
// overlay constraint as RuleEngineTests.swift). Open in Xcode to run.
//
// CLI equivalent: `swift run ReceptacleVerify` covers the same MockMessageSource
// behaviours in the "MockMessageSource" section.

import Foundation
import Testing
@testable import Receptacle

@Suite("Phase 3 — MessageSource Protocol Contract")
struct IMAPSourceTests {

    // All tests use MockMessageSource injected via the MessageSource protocol.
    // This validates the protocol contract independently of any IMAP connection.

    // MARK: fetchItems

    @Test("fetchItems(since: nil) returns all active items")
    func fetchItemsReturnsMappedItems() async throws {
        let source = MockMessageSource()
        let now = Date()
        await source.addItem(MockItem(id: "m1", entityId: "e1", date: now))
        await source.addItem(MockItem(id: "m2", entityId: "e1",
                                      date: now.addingTimeInterval(-3_600)))

        let items = try await source.fetchItems(since: nil)
        #expect(items.count == 2)
        #expect(items.map(\.id).contains("m1"))
        #expect(items.map(\.id).contains("m2"))
    }

    // MARK: archive

    @Test("archive(_:) excludes item from subsequent fetchItems")
    func archiveCallsIMAPMove() async throws {
        let source = MockMessageSource()
        let now = Date()
        let item = MockItem(id: "m1", entityId: "e1", date: now)
        await source.addItem(item)

        try await source.archive(item)

        let afterArchive = try await source.fetchItems(since: nil)
        #expect(afterArchive.isEmpty,
                "archived item must not appear in fetch results")
        let archivedIds = await source.archivedIds
        #expect(archivedIds.contains("m1"),
                "archive must record the item ID")
    }

    // MARK: delete

    @Test("delete(_:) excludes item from subsequent fetchItems")
    func deleteCallsIMAPExpunge() async throws {
        let source = MockMessageSource()
        let now = Date()
        let item = MockItem(id: "m1", entityId: "e1", date: now)
        await source.addItem(item)

        try await source.delete(item)

        let afterDelete = try await source.fetchItems(since: nil)
        #expect(afterDelete.isEmpty,
                "deleted item must not appear in fetch results")
        let deletedIds = await source.deletedIds
        #expect(deletedIds.contains("m1"),
                "delete must record the item ID")
    }

    // MARK: markRead

    @Test("markRead(_:read:) updates the read state of an item")
    func flagSyncMarksRead() async throws {
        let source = MockMessageSource()
        let item = MockItem(id: "m1", entityId: "e1")
        await source.addItem(item)

        try await source.markRead(item, read: true)
        let readIds = await source.readIds
        #expect(readIds.contains("m1"), "markRead(read: true) must record item ID")

        try await source.markRead(item, read: false)
        let readIdsAfter = await source.readIds
        #expect(!readIdsAfter.contains("m1"),
                "markRead(read: false) must remove item ID")
    }

    // MARK: fetchItems(since:)

    @Test("fetchItems(since:) filters items older than the given date")
    func fetchSinceFiltersByDate() async throws {
        let source = MockMessageSource()
        let now = Date()

        let recent = MockItem(id: "recent", entityId: "e1",
                              date: now.addingTimeInterval(-1_800))    // 30 min ago
        let old    = MockItem(id: "old",    entityId: "e1",
                              date: now.addingTimeInterval(-86_400))   // 1 day ago

        await source.addItem(recent)
        await source.addItem(old)

        let cutoff = now.addingTimeInterval(-3_600)   // 1 hour ago
        let filtered = try await source.fetchItems(since: cutoff)

        #expect(filtered.count == 1)
        #expect(filtered[0].id == "recent",
                "only the item within the time window should be returned")
    }

    // MARK: send

    @Test("send(_:) records the reply")
    func sendRecordsReply() async throws {
        let source = MockMessageSource()
        let reply = Reply(itemId: "m1", body: "Thanks!", toAddress: "reply@example.com")

        try await source.send(reply)

        let sent = await source.sentReplies
        #expect(sent.count == 1)
        #expect(sent[0].body == "Thanks!")
        #expect(sent[0].toAddress == "reply@example.com")
    }
}
