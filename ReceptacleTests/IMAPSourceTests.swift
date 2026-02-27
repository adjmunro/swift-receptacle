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

    // MARK: multiple operations

    @Test("archive and delete are independent — different item IDs")
    func archiveAndDeleteAreIndependent() async throws {
        let source = MockMessageSource()
        let now = Date()
        let a = MockItem(id: "a", entityId: "e1", date: now)
        let b = MockItem(id: "b", entityId: "e1", date: now.addingTimeInterval(-60))
        await source.addItem(a)
        await source.addItem(b)

        try await source.archive(a)
        try await source.delete(b)

        let remaining = try await source.fetchItems(since: nil)
        #expect(remaining.isEmpty, "both items removed from fetch")

        let archived = await source.archivedIds
        let deleted  = await source.deletedIds
        #expect(archived.contains("a"), "a is archived")
        #expect(!archived.contains("b"), "b is not archived")
        #expect(deleted.contains("b"),  "b is deleted")
        #expect(!deleted.contains("a"), "a is not deleted")
    }

    @Test("send records multiple replies in order")
    func sendMultipleReplies() async throws {
        let source = MockMessageSource()
        try await source.send(Reply(itemId: "m1", body: "First",  toAddress: "a@b.com"))
        try await source.send(Reply(itemId: "m2", body: "Second", toAddress: "c@d.com"))
        try await source.send(Reply(itemId: "m3", body: "Third",  toAddress: "e@f.com"))

        let sent = await source.sentReplies
        #expect(sent.count == 3)
        #expect(sent[0].body == "First")
        #expect(sent[1].body == "Second")
        #expect(sent[2].body == "Third")
    }
}

// MARK: - IMAPProviderType Tests

@Suite("Phase 3 — IMAPProviderType")
struct IMAPProviderTypeTests {

    // MARK: Host detection

    @Test("detect(fromHost:) identifies Gmail")
    func detectGmail() {
        #expect(IMAPProviderType.detect(fromHost: "imap.gmail.com")      == .gmail)
        #expect(IMAPProviderType.detect(fromHost: "smtp.googlemail.com") == .gmail)
        #expect(IMAPProviderType.detect(fromHost: "IMAP.GMAIL.COM")      == .gmail,
                "detection is case-insensitive")
    }

    @Test("detect(fromHost:) identifies iCloud")
    func detectICloud() {
        #expect(IMAPProviderType.detect(fromHost: "imap.mail.me.com") == .iCloud)
        #expect(IMAPProviderType.detect(fromHost: "imap.icloud.com")  == .iCloud)
        #expect(IMAPProviderType.detect(fromHost: "smtp.mac.com")     == .iCloud)
    }

    @Test("detect(fromHost:) identifies Outlook")
    func detectOutlook() {
        #expect(IMAPProviderType.detect(fromHost: "outlook.office365.com") == .outlook)
        #expect(IMAPProviderType.detect(fromHost: "imap.hotmail.com")      == .outlook)
        #expect(IMAPProviderType.detect(fromHost: "smtp.live.com")         == .outlook)
    }

    @Test("detect(fromHost:) falls back to .custom for unknown hosts")
    func detectCustom() {
        #expect(IMAPProviderType.detect(fromHost: "mail.example.com")     == .custom)
        #expect(IMAPProviderType.detect(fromHost: "imap.mycompany.io")    == .custom)
        #expect(IMAPProviderType.detect(fromHost: "")                     == .custom)
    }

    // MARK: Default configurations

    @Test("Gmail default config")
    func gmailDefaults() {
        #expect(IMAPProviderType.gmail.defaultHost          == "imap.gmail.com")
        #expect(IMAPProviderType.gmail.defaultPort          == 993)
        #expect(IMAPProviderType.gmail.defaultUseTLS        == true)
        #expect(IMAPProviderType.gmail.defaultArchiveFolder == "[Gmail]/All Mail")
        #expect(IMAPProviderType.gmail.defaultAuthMethod    == .oauth2)
        #expect(IMAPProviderType.gmail.defaultSMTPHost      == "smtp.gmail.com")
        #expect(IMAPProviderType.gmail.defaultSMTPPort      == 587)
        #expect(IMAPProviderType.gmail.displayName          == "Gmail")
    }

    @Test("iCloud default config")
    func iCloudDefaults() {
        #expect(IMAPProviderType.iCloud.defaultHost          == "imap.mail.me.com")
        #expect(IMAPProviderType.iCloud.defaultArchiveFolder == "Archive")
        #expect(IMAPProviderType.iCloud.defaultAuthMethod    == .password)
        #expect(IMAPProviderType.iCloud.displayName          == "iCloud")
    }

    @Test("Outlook default config")
    func outlookDefaults() {
        #expect(IMAPProviderType.outlook.defaultHost          == "outlook.office365.com")
        #expect(IMAPProviderType.outlook.defaultArchiveFolder == "Archive")
        #expect(IMAPProviderType.outlook.defaultAuthMethod    == .oauth2)
        #expect(IMAPProviderType.outlook.displayName          == "Outlook")
    }

    @Test("Custom default config")
    func customDefaults() {
        #expect(IMAPProviderType.custom.defaultHost          == "")
        #expect(IMAPProviderType.custom.defaultAuthMethod    == .password)
        #expect(IMAPProviderType.custom.displayName          == "Custom IMAP")
    }

    // MARK: CaseIterable

    @Test("IMAPProviderType has exactly 4 cases")
    func caseIterableCount() {
        #expect(IMAPProviderType.allCases.count == 4)
        #expect(IMAPProviderType.allCases.contains(.gmail))
        #expect(IMAPProviderType.allCases.contains(.iCloud))
        #expect(IMAPProviderType.allCases.contains(.outlook))
        #expect(IMAPProviderType.allCases.contains(.custom))
    }

    // MARK: Auth methods

    @Test("OAuth2 providers: Gmail + Outlook")
    func oauthProviders() {
        let oauthProviders = IMAPProviderType.allCases.filter { $0.defaultAuthMethod == .oauth2 }
        #expect(oauthProviders.contains(.gmail))
        #expect(oauthProviders.contains(.outlook))
        #expect(!oauthProviders.contains(.iCloud))
        #expect(!oauthProviders.contains(.custom))
    }

    @Test("Password providers: iCloud + Custom")
    func passwordProviders() {
        let passwordProviders = IMAPProviderType.allCases.filter { $0.defaultAuthMethod == .password }
        #expect(passwordProviders.contains(.iCloud))
        #expect(passwordProviders.contains(.custom))
        #expect(!passwordProviders.contains(.gmail))
        #expect(!passwordProviders.contains(.outlook))
    }
}
