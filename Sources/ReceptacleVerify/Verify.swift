/// ReceptacleVerify — Phase 0 smoke-test executable.
///
/// Runs assertion-style checks against ReceptacleCore types.
/// Use `swift run ReceptacleVerify` to verify the green baseline without Xcode.
import Foundation
import Receptacle

// MARK: - Helpers

// nonisolated(unsafe): counters are only mutated inside the single async main() context.
nonisolated(unsafe) var passed = 0
nonisolated(unsafe) var failed = 0

func verify(_ condition: Bool, _ label: String) {
    if condition {
        print("  ✅  \(label)")
        passed += 1
    } else {
        print("  ❌  \(label)")
        failed += 1
    }
}

// MARK: - Entry point

@main struct ReceptacleVerify {

    static func main() async {

        // MARK: RetentionPolicy.displayName

        print("\nRetentionPolicy.displayName")
        verify(RetentionPolicy.keepAll.displayName == "Keep all",             "keepAll")
        verify(RetentionPolicy.keepLatest(3).displayName == "Keep latest 3",  "keepLatest(3)")
        verify(RetentionPolicy.keepDays(7).displayName == "Keep 7 days",      "keepDays(7)")
        verify(RetentionPolicy.autoArchive.displayName == "Auto-archive",     "autoArchive")
        verify(RetentionPolicy.autoDelete.displayName == "Auto-delete",       "autoDelete")

        // MARK: ImportanceLevel.Comparable

        print("\nImportanceLevel.Comparable")
        verify(ImportanceLevel.normal    < ImportanceLevel.important, "normal < important")
        verify(ImportanceLevel.important < ImportanceLevel.critical,  "important < critical")
        verify(!(ImportanceLevel.critical < ImportanceLevel.normal),  "!(critical < normal)")

        // MARK: WikilinkParser

        print("\nWikilinkParser")
        let parser = WikilinkParser()
        let markdown = "See [[Project Notes]] and [[Meeting 2026-02-26]] for details."
        let links = parser.extractLinks(from: markdown)
        verify(links.count == 2,                        "two links extracted")
        verify(links[0].target == "Project Notes",      "first target 'Project Notes'")
        verify(links[1].target == "Meeting 2026-02-26", "second target 'Meeting 2026-02-26'")

        let noLinks = parser.extractLinks(from: "No wikilinks here.")
        verify(noLinks.isEmpty, "empty input returns []")

        let resolved = parser.resolve(
            markdown: "See [[Project Notes]] and [[Unknown Note]]."
        ) { target in
            target == "Project Notes" ? "note-abc123" : nil
        }
        verify(resolved.resolvedIds["Project Notes"] == "note-abc123",
               "known target resolves to ID")
        verify(resolved.unresolvedTargets.contains("Unknown Note"),
               "unknown target in unresolved list")

        // MARK: RuleEngine

        print("\nRuleEngine")
        let engine = RuleEngine()
        let now = Date()

        // keepAll — nothing removed
        let keepAllEntity = EntitySnapshot(id: "e1", retentionPolicy: .keepAll)
        let items3 = (0..<3).map { i in
            ItemSnapshot(id: "i\(i)", entityId: "e1",
                         date: now.addingTimeInterval(Double(-i * 86400)))
        }
        let r1 = engine.evaluate(items: items3, entity: keepAllEntity, now: now)
        verify(r1.itemsToDelete.isEmpty,  "keepAll: nothing deleted")
        verify(r1.itemsToArchive.isEmpty, "keepAll: nothing archived")

        // keepLatest(1) — keeps newest (index 0), deletes the rest
        let keepLatestEntity = EntitySnapshot(id: "e2", retentionPolicy: .keepLatest(1))
        let r2 = engine.evaluate(items: items3, entity: keepLatestEntity, now: now)
        verify(r2.itemsToDelete.count == 2,       "keepLatest(1): 2 older items deleted")
        verify(!r2.itemsToDelete.contains("i0"),  "keepLatest(1): newest item kept")

        // keepDays(7) — items older than 7 days deleted
        let old    = ItemSnapshot(id: "old",    entityId: "e3",
                                  date: now.addingTimeInterval(-8 * 86400))
        let recent = ItemSnapshot(id: "recent", entityId: "e3",
                                  date: now.addingTimeInterval(-1 * 86400))
        let keepDaysEntity = EntitySnapshot(id: "e3", retentionPolicy: .keepDays(7))
        let r3 = engine.evaluate(items: [old, recent], entity: keepDaysEntity, now: now)
        verify(r3.itemsToDelete.contains("old"),     "keepDays(7): old item deleted")
        verify(!r3.itemsToDelete.contains("recent"), "keepDays(7): recent item kept")

        // autoArchive
        let archiveEntity = EntitySnapshot(id: "e4", retentionPolicy: .autoArchive)
        let r4 = engine.evaluate(items: [recent], entity: archiveEntity, now: now)
        verify(r4.itemsToArchive.contains("recent"), "autoArchive: item archived")
        verify(r4.itemsToDelete.isEmpty,             "autoArchive: nothing deleted")

        // autoDelete
        let deleteEntity = EntitySnapshot(id: "e5", retentionPolicy: .autoDelete)
        let r5 = engine.evaluate(items: [recent], entity: deleteEntity, now: now)
        verify(r5.itemsToDelete.contains("recent"), "autoDelete: item deleted")
        verify(r5.itemsToArchive.isEmpty,           "autoDelete: nothing archived")

        // subRule overrides entity policy
        let receiptItem = ItemSnapshot(id: "receipt", entityId: "e6", date: now,
                                       subject: "Your Order #1234")
        let orderRule = SubRule(matchType: .subjectContains, pattern: "Order", action: .keepAll)
        let subRuleEntity = EntitySnapshot(id: "e6", retentionPolicy: .autoDelete,
                                           subRules: [orderRule])
        let r6 = engine.evaluate(items: [receiptItem], entity: subRuleEntity, now: now)
        verify(r6.itemsToDelete.isEmpty,  "subRule: matching item not deleted by entity policy")
        verify(r6.itemsToArchive.isEmpty, "subRule: matching item not archived")

        // empty items
        let r7 = engine.evaluate(items: [], entity: keepAllEntity, now: now)
        verify(r7.itemsToDelete.isEmpty,  "empty items: delete list empty")
        verify(r7.itemsToArchive.isEmpty, "empty items: archive list empty")

        // MARK: EntitySortKey

        print("\nEntitySortKey")
        let k1 = EntitySortKey(importanceLevel: .critical,  displayName: "Zara")
        let k2 = EntitySortKey(importanceLevel: .important, displayName: "Alice")
        let k3 = EntitySortKey(importanceLevel: .normal,    displayName: "Alice")
        let k4 = EntitySortKey(importanceLevel: .normal,    displayName: "Bob")
        verify(k1 < k2, "critical sorts before important")
        verify(k2 < k3, "important sorts before normal")
        verify(k3 < k4, "same level: Alice before Bob (alphabetical)")
        verify(!(k4 < k3), "same level: Bob not before Alice")

        let unsorted = [k4, k2, k1, k3]
        let sorted = unsorted.sorted()
        verify(sorted[0] == k1, "sort[0] = critical/Zara")
        verify(sorted[1] == k2, "sort[1] = important/Alice")
        verify(sorted[2] == k3, "sort[2] = normal/Alice")
        verify(sorted[3] == k4, "sort[3] = normal/Bob")

        // MARK: EntitySnapshot — action availability

        print("\nEntitySnapshot action availability")
        let protectedSnap   = EntitySnapshot(id: "p", retentionPolicy: .keepAll, protectionLevel: .protected)
        let normalSnap      = EntitySnapshot(id: "n", retentionPolicy: .keepAll, protectionLevel: .normal)
        let apocalypticSnap = EntitySnapshot(id: "a", retentionPolicy: .keepAll, protectionLevel: .apocalyptic)

        verify(!protectedSnap.allowsAutoDelete,    "protected: no auto-delete")
        verify(!protectedSnap.showsDeleteAll,      "protected: no deleteAll")
        verify(normalSnap.allowsAutoDelete,        "normal: allows auto-delete")
        verify(!normalSnap.showsDeleteAll,         "normal: no deleteAll shortcut")
        verify(apocalypticSnap.allowsAutoDelete,   "apocalyptic: allows auto-delete")
        verify(apocalypticSnap.showsDeleteAll,     "apocalyptic: shows deleteAll")

        // MARK: RuleEngine — Phase 1 additions

        print("\nRuleEngine (Phase 1)")

        // keepLatest(2) with 5 items — keeps 2 newest
        let fiveItems = (0..<5).map { i in
            ItemSnapshot(id: "p\(i)", entityId: "ex",
                         date: now.addingTimeInterval(Double(-i) * 86400))
        }
        let keepTwo = EntitySnapshot(id: "ex", retentionPolicy: .keepLatest(2))
        let r8 = engine.evaluate(items: fiveItems, entity: keepTwo, now: now)
        verify(r8.itemsToDelete.count == 3,        "keepLatest(2): 3 of 5 items deleted")
        verify(!r8.itemsToDelete.contains("p0"),   "keepLatest(2): newest kept")
        verify(!r8.itemsToDelete.contains("p1"),   "keepLatest(2): second kept")
        verify(r8.itemsToDelete.contains("p2"),    "keepLatest(2): third deleted")

        // keepDays boundary — item at 7d-1s is kept; item at 8d is deleted
        let borderItem = ItemSnapshot(id: "border", entityId: "ey",
                                      date: now.addingTimeInterval(-7 * 86400 + 1))
        let staleItem  = ItemSnapshot(id: "stale",  entityId: "ey",
                                      date: now.addingTimeInterval(-8 * 86400))
        let keepDays7 = EntitySnapshot(id: "ey", retentionPolicy: .keepDays(7))
        let r9 = engine.evaluate(items: [borderItem, staleItem], entity: keepDays7, now: now)
        verify(!r9.itemsToDelete.contains("border"), "keepDays(7): border item (7d-1s) kept")
        verify(r9.itemsToDelete.contains("stale"),   "keepDays(7): stale item (8d) deleted")

        // protected entity — nothing deleted even under keepDays(7) + stale item
        let protectedEntity = EntitySnapshot(id: "ep", retentionPolicy: .keepDays(7),
                                              protectionLevel: .protected)
        let r10 = engine.evaluate(items: [staleItem], entity: protectedEntity, now: now)
        verify(r10.itemsToDelete.isEmpty, "protected entity: no auto-deletion")

        // importance pattern — subject match elevates to .critical
        let rateItem = ItemSnapshot(id: "rate", entityId: "ei", date: now,
                                    subject: "Your interest rates have changed")
        let plainItem = ItemSnapshot(id: "plain", entityId: "ei", date: now,
                                     subject: "Monthly digest")
        let importancePattern = ImportancePattern(matchType: .subjectContains,
                                                  pattern: "rates",
                                                  elevatedLevel: .critical)
        let importanceEntity = EntitySnapshot(id: "ei", retentionPolicy: .keepAll,
                                               importancePatterns: [importancePattern])
        let r11 = engine.evaluate(items: [rateItem, plainItem], entity: importanceEntity, now: now)
        verify(r11.elevatedImportance["rate"] == .critical,
               "importance pattern: matching item elevated to .critical")
        verify(r11.elevatedImportance["plain"] == nil,
               "importance pattern: non-matching item has no elevation")

        // multiple patterns — highest wins
        let urgentItem = ItemSnapshot(id: "urgent", entityId: "em", date: now,
                                      subject: "Urgent rates security alert")
        let p1 = ImportancePattern(matchType: .subjectContains,
                                   pattern: "rates", elevatedLevel: .important)
        let p2 = ImportancePattern(matchType: .subjectContains,
                                   pattern: "Urgent", elevatedLevel: .critical)
        let multiEntity = EntitySnapshot(id: "em", retentionPolicy: .keepAll,
                                          importancePatterns: [p1, p2])
        let r12 = engine.evaluate(items: [urgentItem], entity: multiEntity, now: now)
        verify(r12.elevatedImportance["urgent"] == .critical,
               "multiple patterns: highest level wins")

        // MARK: AIPermissionManager

        print("\nAIPermissionManager")
        let manager = AIPermissionManager()

        let defaultScope = await manager.scope(for: "openai", feature: .summarise)
        verify(defaultScope == .askEachTime, "default scope is askEachTime")

        await manager.set(scope: .always, providerId: "openai", feature: .summarise)
        let setScope = await manager.scope(for: "openai", feature: .summarise)
        verify(setScope == .always, "set scope respected")

        let isAllowed = await manager.isAllowed(providerId: "openai", feature: .summarise)
        verify(isAllowed, "isAllowed returns true after .always")

        await manager.set(scope: .never, providerId: "claude", feature: .transcribe)
        let isDenied = await manager.isDenied(providerId: "claude", feature: .transcribe)
        verify(isDenied, "isDenied returns true after .never")

        // entity-level overrides global
        await manager.set(scope: .always, providerId: "openai", feature: .summarise)
        await manager.set(scope: .never,  providerId: "openai", feature: .summarise,
                          entityId: "entity-1")
        let entityScope = await manager.scope(for: "openai", feature: .summarise,
                                               entityId: "entity-1")
        verify(entityScope == .never,     "entity scope overrides global")
        let globalStillAlways = await manager.scope(for: "openai", feature: .summarise)
        verify(globalStillAlways == .always, "global scope unchanged after entity override")

        // MARK: AttachmentMatcher

        print("\nAttachmentMatcher")
        let am = AttachmentMatcher()

        // Empty MIME list — passes all
        let allMIME = AttachmentAction(mimeTypes: [], saveDestination: .iCloudDrive(subfolder: "Test"))
        verify(am.matchesMIMEType("application/pdf", action: allMIME), "empty mimeTypes: pdf passes")
        verify(am.matchesMIMEType("image/png",        action: allMIME), "empty mimeTypes: png passes")

        // MIME type match
        let pdfOnly = AttachmentAction(mimeTypes: ["application/pdf"],
                                        saveDestination: .iCloudDrive(subfolder: "Receipts"))
        verify(am.matchesMIMEType("application/pdf", action: pdfOnly),  "matching MIME passes")
        verify(!am.matchesMIMEType("image/jpeg",      action: pdfOnly),  "non-matching MIME skips")

        // Case-insensitive MIME
        let upperPDF = AttachmentAction(mimeTypes: ["APPLICATION/PDF"],
                                         saveDestination: .iCloudDrive(subfolder: "Docs"))
        verify(am.matchesMIMEType("application/pdf", action: upperPDF), "MIME match is case-insensitive")

        // Multiple MIME types
        let multiMIME = AttachmentAction(mimeTypes: ["application/pdf", "image/png"],
                                          saveDestination: .iCloudDrive(subfolder: "Mixed"))
        verify(am.matchesMIMEType("application/pdf", action: multiMIME), "multi-MIME: pdf matches")
        verify(am.matchesMIMEType("image/png",        action: multiMIME), "multi-MIME: png matches")
        verify(!am.matchesMIMEType("audio/mp3",       action: multiMIME), "multi-MIME: mp3 skips")

        // Nil filename pattern — passes all
        let noPattern = AttachmentAction(filenamePattern: nil, mimeTypes: [],
                                          saveDestination: .iCloudDrive(subfolder: "All"))
        verify(am.matchesFilename("receipt.pdf", action: noPattern), "nil pattern: any filename passes")

        // Filename pattern match (case-insensitive substring)
        let receiptPattern = AttachmentAction(filenamePattern: "receipt", mimeTypes: [],
                                               saveDestination: .iCloudDrive(subfolder: "Receipts"))
        verify(am.matchesFilename("amazon-receipt-2026.pdf", action: receiptPattern),
               "filename pattern: substring match passes")
        verify(am.matchesFilename("RECEIPT_001.PDF", action: receiptPattern),
               "filename pattern: case-insensitive match passes")
        verify(!am.matchesFilename("photo.jpg", action: receiptPattern),
               "filename pattern: non-matching skips")

        // Combined filter
        let combined = AttachmentAction(filenamePattern: "receipt", mimeTypes: ["application/pdf"],
                                         saveDestination: .iCloudDrive(subfolder: "Receipts"))
        verify(am.matches(filename: "amazon-receipt.pdf",   mimeType: "application/pdf", action: combined),
               "combined: both pass → matches")
        verify(!am.matches(filename: "amazon-receipt.pdf",  mimeType: "image/jpeg",      action: combined),
               "combined: MIME fails → skips")
        verify(!am.matches(filename: "photo.pdf",           mimeType: "application/pdf", action: combined),
               "combined: filename fails → skips")

        // skipReason
        let skipNil = am.skipReason(filename: "doc.pdf", mimeType: "application/pdf", action: pdfOnly)
        verify(skipNil == nil, "skipReason nil when attachment matches")
        let skipMsg = am.skipReason(filename: "photo.jpg", mimeType: "image/jpeg", action: pdfOnly)
        verify(skipMsg != nil,                      "skipReason non-nil when MIME mismatches")
        verify(skipMsg?.contains("image/jpeg") == true, "skipReason contains MIME type")

        // QuotedRangeDetector

        print("\nQuotedRangeDetector")
        let qd = QuotedRangeDetector()

        // Blockquote detection
        let htmlWithQuote = "Hello <blockquote>On Wed, you wrote:\nSome text</blockquote> Cheers"
        let bqRanges = qd.detect(in: htmlWithQuote)
        verify(bqRanges.contains { $0.kind == .blockquote }, "detect: <blockquote> element")
        let bqRange = bqRanges.first(where: { $0.kind == .blockquote })!.range
        verify(htmlWithQuote[bqRange].contains("On Wed"), "blockquote range covers content")

        // Multiple blockquotes
        let multi = "<blockquote>First</blockquote> text <blockquote>Second</blockquote>"
        let multiRanges = qd.detect(in: multi).filter { $0.kind == .blockquote }
        verify(multiRanges.count == 2, "detect: multiple blockquotes")

        // Case-insensitive blockquote
        let upper = "Text <BLOCKQUOTE>Quoted</BLOCKQUOTE> more"
        verify(qd.detect(in: upper).contains { $0.kind == .blockquote },
               "detect: case-insensitive BLOCKQUOTE")

        // GT-prefix detection
        let gtText = "My reply.\n> Line one\n> Line two\nEnd."
        let gtRanges = qd.detect(in: gtText)
        verify(gtRanges.contains { $0.kind == .gtPrefix }, "detect: > prefix lines")
        verify(gtRanges.filter { $0.kind == .gtPrefix }.count == 1,
               "detect: consecutive > lines merged into one range")

        // Separated > blocks → two ranges
        let twoBlocks = "> Block A\nPlain\n> Block B"
        let twoGt = qd.detect(in: twoBlocks).filter { $0.kind == .gtPrefix }
        verify(twoGt.count == 2, "detect: separated > blocks produce 2 ranges")

        // Signature separator
        let sigText = "Hi there.\n-- \nJohn Smith\njohn@example.com"
        let sigRanges = qd.detect(in: sigText)
        verify(sigRanges.contains { $0.kind == .signature }, "detect: -- signature separator")
        let sigRange = sigRanges.first(where: { $0.kind == .signature })!.range
        verify(sigRange.upperBound == sigText.endIndex, "signature range extends to end")

        // Plain text — no ranges
        let plain = "Hi! Just checking in. Hope you're well!"
        verify(qd.detect(in: plain).isEmpty, "detect: plain text returns empty")
        verify(qd.detect(in: "").isEmpty,    "detect: empty string returns empty")

        // collapsedText helper
        let mixedText = "My reply here.\n> You wrote this.\n> And this.\nCheers."
        let collapsed = qd.collapsedText(for: mixedText)
        verify(collapsed == "My reply here.\n", "collapsedText: text before first quoted range")
        let noQuote = "No quoted content here."
        verify(qd.collapsedText(for: noQuote) == noQuote,
               "collapsedText: full text when no quotes")

        // hasQuotedContent helper
        verify(qd.hasQuotedContent(in: "<blockquote>Q</blockquote>"),
               "hasQuotedContent: true for blockquote")
        verify(!qd.hasQuotedContent(in: "Plain text"),
               "hasQuotedContent: false for plain text")

        // FeedTypes

        print("\nFeedTypes")

        // FeedItemRecord conforms to Item
        let feedRecord = FeedItemRecord(
            id: "swift-blog:guid-123",
            entityId: "entity-swift",
            sourceId: "swift-blog",
            date: Date(),
            title: "Swift 6.2 Released",
            linkURL: "https://www.swift.org/blog/swift-6-2-released/",
            contentHTML: "<p>Announcing <strong>Swift 6.2</strong>.</p>",
            format: .rss
        )
        verify(feedRecord.id       == "swift-blog:guid-123",   "FeedItemRecord id")
        verify(feedRecord.entityId == "entity-swift",           "FeedItemRecord entityId")
        verify(feedRecord.sourceId == "swift-blog",             "FeedItemRecord sourceId")
        verify(feedRecord.title    == "Swift 6.2 Released",     "FeedItemRecord title")
        verify(feedRecord.format   == .rss,                     "FeedItemRecord format = .rss")
        verify(!feedRecord.summary.isEmpty,                     "FeedItemRecord summary auto-filled")

        // makeId
        let compositeId = FeedItemRecord.makeId(feedId: "blog", guid: "post-42")
        verify(compositeId == "blog:post-42", "makeId builds composite ID")

        // plainSummary — HTML stripping
        let feedHtml = "<p>We are pleased to announce <strong>Swift 6.2</strong>.</p>"
        let feedPlain = FeedItemRecord.plainSummary(from: feedHtml)
        verify(!feedPlain.contains("<"),            "plainSummary: no opening tags")
        verify(!feedPlain.contains(">"),            "plainSummary: no closing tags")
        verify(feedPlain.contains("Swift 6.2"),     "plainSummary: content preserved")

        // plainSummary — entity decoding
        let entities = "Swift &amp; Objective-C &lt;rocks&gt; &quot;nice&quot;"
        let decoded = FeedItemRecord.plainSummary(from: entities)
        verify(decoded.contains("Swift & Objective-C"), "plainSummary: &amp; decoded")
        verify(decoded.contains("<rocks>"),              "plainSummary: &lt;&gt; decoded")
        verify(decoded.contains("\"nice\""),             "plainSummary: &quot; decoded")

        // plainSummary — truncation
        let longContent = String(repeating: "word ", count: 100)
        let truncated = FeedItemRecord.plainSummary(from: longContent, maxLength: 50)
        verify(truncated.hasSuffix("…"), "plainSummary: truncated with ellipsis")

        // summary auto-fills from title when not provided
        let noSummary = FeedItemRecord(
            id: "x:1", entityId: "e", sourceId: "x",
            title: "My Article Title"
        )
        verify(noSummary.summary == "My Article Title",
               "FeedItemRecord: summary auto-filled from title")

        // FeedFormat cases
        verify(FeedFormat.rss.rawValue  == "rss",  "FeedFormat.rss rawValue")
        verify(FeedFormat.atom.rawValue == "atom",  "FeedFormat.atom rawValue")
        verify(FeedFormat.json.rawValue == "json",  "FeedFormat.json rawValue")
        verify(FeedFormat.allCases.count == 3,      "FeedFormat has 3 cases")

        // FeedConfig round-trip
        let feedConfig = FeedConfig(
            feedId: "swift-blog",
            displayName: "Swift.org Blog",
            feedURLString: "https://www.swift.org/atom.xml",
            entityId: "entity-swift"
        )
        verify(feedConfig.feedId         == "swift-blog",            "FeedConfig feedId")
        verify(feedConfig.displayName    == "Swift.org Blog",        "FeedConfig displayName")
        verify(feedConfig.feedURLString  == "https://www.swift.org/atom.xml", "FeedConfig URL")
        verify(feedConfig.entityId       == "entity-swift",          "FeedConfig entityId")

        // IMAPProviderType

        print("\nIMAPProviderType")

        // Provider detection from hostname
        verify(IMAPProviderType.detect(fromHost: "imap.gmail.com")        == .gmail,   "detect gmail.com → .gmail")
        verify(IMAPProviderType.detect(fromHost: "smtp.googlemail.com")   == .gmail,   "detect googlemail.com → .gmail")
        verify(IMAPProviderType.detect(fromHost: "imap.mail.me.com")      == .iCloud,  "detect me.com → .iCloud")
        verify(IMAPProviderType.detect(fromHost: "imap.icloud.com")       == .iCloud,  "detect icloud.com → .iCloud")
        verify(IMAPProviderType.detect(fromHost: "outlook.office365.com") == .outlook, "detect office365 → .outlook")
        verify(IMAPProviderType.detect(fromHost: "imap.hotmail.com")      == .outlook, "detect hotmail → .outlook")
        verify(IMAPProviderType.detect(fromHost: "mail.example.com")      == .custom,  "detect custom host → .custom")

        // Default configs
        verify(IMAPProviderType.gmail.defaultHost   == "imap.gmail.com",          "gmail default host")
        verify(IMAPProviderType.gmail.defaultPort   == 993,                        "gmail default port")
        verify(IMAPProviderType.gmail.defaultUseTLS == true,                       "gmail uses TLS")
        verify(IMAPProviderType.gmail.defaultArchiveFolder == "[Gmail]/All Mail",  "gmail archive folder")
        verify(IMAPProviderType.gmail.defaultAuthMethod    == .oauth2,             "gmail auth = oauth2")

        verify(IMAPProviderType.iCloud.defaultHost   == "imap.mail.me.com",        "iCloud default host")
        verify(IMAPProviderType.iCloud.defaultArchiveFolder == "Archive",           "iCloud archive folder")
        verify(IMAPProviderType.iCloud.defaultAuthMethod    == .password,           "iCloud auth = password")

        verify(IMAPProviderType.outlook.defaultHost   == "outlook.office365.com",  "outlook default host")
        verify(IMAPProviderType.outlook.defaultArchiveFolder == "Archive",          "outlook archive folder")
        verify(IMAPProviderType.outlook.defaultAuthMethod    == .oauth2,            "outlook auth = oauth2")

        verify(IMAPProviderType.custom.defaultAuthMethod == .password,              "custom auth = password")

        // Display names
        verify(IMAPProviderType.gmail.displayName   == "Gmail",       "gmail displayName")
        verify(IMAPProviderType.iCloud.displayName  == "iCloud",      "iCloud displayName")
        verify(IMAPProviderType.outlook.displayName == "Outlook",     "outlook displayName")
        verify(IMAPProviderType.custom.displayName  == "Custom IMAP", "custom displayName")

        // MockMessageSource

        print("\nMockMessageSource")

        do {
            let now2 = Date()

            // fetchItems(since: nil) returns all active items
            let mockSource = MockMessageSource()
            await mockSource.addItem(MockItem(id: "m1", entityId: "e1", date: now2))
            await mockSource.addItem(MockItem(id: "m2", entityId: "e1",
                                              date: now2.addingTimeInterval(-3_600)))
            let allItems = try await mockSource.fetchItems(since: nil)
            verify(allItems.count == 2, "fetchItems(nil): returns all 2 items")
            verify(allItems.map(\.id).contains("m1"), "fetchItems(nil): m1 present")
            verify(allItems.map(\.id).contains("m2"), "fetchItems(nil): m2 present")

            // archive removes item from fetchItems
            let archiveSource = MockMessageSource()
            let archiveItem = MockItem(id: "a1", entityId: "e1", date: now2)
            await archiveSource.addItem(archiveItem)
            try await archiveSource.archive(archiveItem)
            let afterArchive = try await archiveSource.fetchItems(since: nil)
            verify(afterArchive.isEmpty, "archive: item excluded from fetch")
            let archivedIds = await archiveSource.archivedIds
            verify(archivedIds.contains("a1"), "archive: ID recorded in archivedIds")

            // delete removes item from fetchItems
            let deleteSource = MockMessageSource()
            let deleteItem = MockItem(id: "d1", entityId: "e1", date: now2)
            await deleteSource.addItem(deleteItem)
            try await deleteSource.delete(deleteItem)
            let afterDelete = try await deleteSource.fetchItems(since: nil)
            verify(afterDelete.isEmpty, "delete: item excluded from fetch")
            let deletedIds = await deleteSource.deletedIds
            verify(deletedIds.contains("d1"), "delete: ID recorded in deletedIds")

            // markRead toggles membership in readIds
            let readSource = MockMessageSource()
            let readItem = MockItem(id: "r1", entityId: "e1")
            await readSource.addItem(readItem)
            try await readSource.markRead(readItem, read: true)
            let readIds = await readSource.readIds
            verify(readIds.contains("r1"), "markRead(true): ID in readIds")
            try await readSource.markRead(readItem, read: false)
            let readIdsAfter = await readSource.readIds
            verify(!readIdsAfter.contains("r1"), "markRead(false): ID removed from readIds")

            // fetchItems(since:) filters by date
            let sinceSource = MockMessageSource()
            let recentItem = MockItem(id: "recent", entityId: "e1",
                                      date: now2.addingTimeInterval(-1_800))   // 30 min ago
            let oldItem    = MockItem(id: "old",    entityId: "e1",
                                      date: now2.addingTimeInterval(-86_400))  // 1 day ago
            await sinceSource.addItem(recentItem)
            await sinceSource.addItem(oldItem)
            let cutoff = now2.addingTimeInterval(-3_600)  // 1 hour ago
            let filtered = try await sinceSource.fetchItems(since: cutoff)
            verify(filtered.count == 1,           "fetchItems(since:): 1 item returned")
            verify(filtered[0].id == "recent",    "fetchItems(since:): recent item kept")

            // send records reply
            let sendSource = MockMessageSource()
            let reply = Reply(itemId: "m1", body: "Thanks!", toAddress: "reply@example.com")
            try await sendSource.send(reply)
            let sentReplies = await sendSource.sentReplies
            verify(sentReplies.count == 1,                          "send: 1 reply recorded")
            verify(sentReplies[0].body == "Thanks!",                "send: body correct")
            verify(sentReplies[0].toAddress == "reply@example.com", "send: toAddress correct")

        } catch {
            verify(false, "MockMessageSource: unexpected throw — \(error)")
        }

        // MARK: MockAIProvider

        print("\nMockAIProvider")

        do {
            // Default responses
            let mockAI = MockAIProvider()
            let summary = try await mockAI.summarise(text: "Long email body here.")
            verify(summary == "Mock summary.", "default summarise result")

            let reframed = try await mockAI.reframe(text: "hey thanks", tone: .formal)
            verify(reframed == "Mock reframe.", "default reframe result")

            // Call tracking
            let summariseCount = await mockAI.summariseCalled
            verify(summariseCount == 1, "summariseCalled == 1 after one call")
            let lastInput = await mockAI.lastSummariseInput
            verify(lastInput == "Long email body here.", "lastSummariseInput recorded")
            let lastTone = await mockAI.lastReframeTone
            verify(lastTone == .formal, "lastReframeTone recorded")

            // Configured result
            await mockAI.set(summariseResult: "Custom summary.")
            let custom = try await mockAI.summarise(text: "anything")
            verify(custom == "Custom summary.", "set(summariseResult:) respected")

            let summariseCount2 = await mockAI.summariseCalled
            verify(summariseCount2 == 2, "summariseCalled increments cumulatively")

            // resetCallCounts
            await mockAI.resetCallCounts()
            let afterReset = await mockAI.summariseCalled
            verify(afterReset == 0, "resetCallCounts: summariseCalled reset to 0")
            let afterResetInput = await mockAI.lastSummariseInput
            verify(afterResetInput == nil, "resetCallCounts: lastSummariseInput nil")

            // Error injection
            await mockAI.set(shouldThrow: .rateLimited)
            var didThrow = false
            do {
                _ = try await mockAI.summarise(text: "fail")
            } catch AIProviderError.rateLimited {
                didThrow = true
            }
            verify(didThrow, "set(shouldThrow: .rateLimited): summarise throws")

            // Clear error injection
            await mockAI.set(shouldThrow: nil)
            let recovered = try await mockAI.summarise(text: "recovered")
            verify(!recovered.isEmpty, "cleared shouldThrow: summarise succeeds again")

        } catch {
            verify(false, "MockAIProvider: unexpected throw — \(error)")
        }

        // MARK: AIGate

        print("\nAIGate")

        do {
            // .never → permissionDenied
            let mgr1 = AIPermissionManager()
            await mgr1.set(scope: .never, providerId: "openai", feature: .summarise)
            let gate1 = AIGate(permissionManager: mgr1)
            var blocked = false
            do {
                _ = try await gate1.perform(providerId: "openai", feature: .summarise) {
                    "should not reach"
                }
            } catch AIProviderError.permissionDenied {
                blocked = true
            }
            verify(blocked, "AIGate: .never → permissionDenied thrown")

            // .always → proceeds
            let mgr2 = AIPermissionManager()
            await mgr2.set(scope: .always, providerId: "claude", feature: .summarise)
            let gate2 = AIGate(permissionManager: mgr2)
            let result = try await gate2.perform(providerId: "claude", feature: .summarise) {
                "gate result"
            }
            verify(result == "gate result", "AIGate: .always → operation result returned")

            // .askEachTime → proceeds (UI confirms externally)
            let mgr3 = AIPermissionManager()
            await mgr3.set(scope: .askEachTime, providerId: "claude", feature: .reframeTone)
            let gate3 = AIGate(permissionManager: mgr3)
            let askResult = try await gate3.perform(providerId: "claude", feature: .reframeTone) {
                "ask result"
            }
            verify(askResult == "ask result", "AIGate: .askEachTime → operation proceeds")

            // Entity override: global .always, entity .never
            let mgr4 = AIPermissionManager()
            await mgr4.set(scope: .always, providerId: "openai", feature: .summarise)
            await mgr4.set(scope: .never,  providerId: "openai", feature: .summarise,
                           entityId: "private-entity")
            let gate4 = AIGate(permissionManager: mgr4)

            let globalOK = try await gate4.perform(providerId: "openai", feature: .summarise) {
                "global ok"
            }
            verify(globalOK == "global ok", "AIGate: global .always proceeds without entity")

            var entityBlocked = false
            do {
                _ = try await gate4.perform(
                    providerId: "openai", feature: .summarise, entityId: "private-entity"
                ) { "blocked" }
            } catch AIProviderError.permissionDenied {
                entityBlocked = true
            }
            verify(entityBlocked, "AIGate: entity .never blocks even when global is .always")

            // Convenience predicates
            let mgr5 = AIPermissionManager()
            await mgr5.set(scope: .always,      providerId: "openai", feature: .summarise)
            await mgr5.set(scope: .never,       providerId: "openai", feature: .transcribe)
            await mgr5.set(scope: .askEachTime, providerId: "openai", feature: .reframeTone)
            let gate5 = AIGate(permissionManager: mgr5)

            let isAlways = await gate5.isAlwaysAllowed(providerId: "openai", feature: .summarise)
            verify(isAlways, "isAlwaysAllowed: true for .always scope")
            let isBlocked = await gate5.isBlocked(providerId: "openai", feature: .transcribe)
            verify(isBlocked, "isBlocked: true for .never scope")
            let needsConfirm = await gate5.requiresConfirmation(providerId: "openai", feature: .reframeTone)
            verify(needsConfirm, "requiresConfirmation: true for .askEachTime scope")

            let notAlways = await gate5.isAlwaysAllowed(providerId: "openai", feature: .transcribe)
            verify(!notAlways, "isAlwaysAllowed: false for .never scope")

        } catch {
            verify(false, "AIGate: unexpected throw — \(error)")
        }

        // MARK: Summary

        print("\n─────────────────────────────────────────")
        if failed == 0 {
            print("  ✅  All \(passed) checks passed — Phase 8 green baseline confirmed.")
        } else {
            print("  ❌  \(failed) check(s) FAILED out of \(passed + failed).")
        }
        print("─────────────────────────────────────────\n")

        exit(failed > 0 ? 1 : 0)
    }
}
