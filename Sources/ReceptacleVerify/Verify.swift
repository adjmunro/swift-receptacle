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

        // MARK: MockMessageSource

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

        // MARK: Summary

        print("\n─────────────────────────────────────────")
        if failed == 0 {
            print("  ✅  All \(passed) checks passed — Phase 3 green baseline confirmed.")
        } else {
            print("  ❌  \(failed) check(s) FAILED out of \(passed + failed).")
        }
        print("─────────────────────────────────────────\n")

        exit(failed > 0 ? 1 : 0)
    }
}
