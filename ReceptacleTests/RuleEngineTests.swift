// ReceptacleTests/RuleEngineTests.swift
//
// IMPORTANT: This file is EXCLUDED from the Package.swift CLI build.
// Reason: importing both `Foundation` and `Testing` in the same file triggers
// the `_Testing_Foundation` cross-import overlay, whose `.swiftmodule` is
// binary-only in Command Line Tools (no Swift module interface — compile error).
//
// To run these tests: open Receptacle.xcodeproj in Xcode and run the
// ReceptacleTests scheme. Xcode ships the full _Testing_Foundation.swiftmodule.
//
// CLI equivalent coverage: `swift run ReceptacleVerify` (all cases mirrored there).

import Foundation
import Testing
@testable import Receptacle

@Suite("Phase 1 — Rule Engine (date-dependent)")
struct RuleEngineTests {

    let engine = RuleEngine()

    // MARK: keepLatest

    @Test("keepLatest(2) keeps newest 2, deletes the rest")
    func keepLatestRemovesOlderItems() {
        let now = Date()
        // items[0] is newest, items[4] is oldest
        let items = (0..<5).map { i in
            ItemSnapshot(id: "i\(i)", entityId: "e1",
                         date: now.addingTimeInterval(Double(-i) * 86400))
        }
        let entity = EntitySnapshot(id: "e1", retentionPolicy: .keepLatest(2))
        let result = engine.evaluate(items: items, entity: entity, now: now)

        #expect(result.itemsToDelete.count == 3)
        #expect(!result.itemsToDelete.contains("i0"))  // newest — kept
        #expect(!result.itemsToDelete.contains("i1"))  // second — kept
        #expect(result.itemsToDelete.contains("i2"))
        #expect(result.itemsToDelete.contains("i3"))
        #expect(result.itemsToDelete.contains("i4"))
    }

    // MARK: keepDays

    @Test("keepDays(7) deletes items older than 7 days, keeps recent + border")
    func keepDaysRemovesExpiredItems() {
        let now = Date()
        let expired = ItemSnapshot(id: "expired", entityId: "e1",
                                   date: now.addingTimeInterval(-8 * 86400))
        let fresh   = ItemSnapshot(id: "fresh",   entityId: "e1",
                                   date: now.addingTimeInterval(-3 * 86400))
        // Exactly at the boundary — 7 days minus 1 second → still within window
        let border  = ItemSnapshot(id: "border",  entityId: "e1",
                                   date: now.addingTimeInterval(-7 * 86400 + 1))
        let entity = EntitySnapshot(id: "e1", retentionPolicy: .keepDays(7))
        let result = engine.evaluate(items: [expired, fresh, border], entity: entity, now: now)

        #expect(result.itemsToDelete.contains("expired"))
        #expect(!result.itemsToDelete.contains("fresh"))
        #expect(!result.itemsToDelete.contains("border"))
    }

    // MARK: subRule override

    @Test("subRule overrides entity-level autoDelete for matching items")
    func subRuleOverridesEntityPolicy() {
        let now = Date()
        let order  = ItemSnapshot(id: "order",  entityId: "e1", date: now,
                                  subject: "Your Order #1234")
        let promo  = ItemSnapshot(id: "promo",  entityId: "e1", date: now,
                                  subject: "Weekend sale newsletter")
        let rule = SubRule(matchType: .subjectContains, pattern: "Order", action: .keepAll)
        let entity = EntitySnapshot(id: "e1", retentionPolicy: .autoDelete, subRules: [rule])
        let result = engine.evaluate(items: [order, promo], entity: entity, now: now)

        #expect(!result.itemsToDelete.contains("order"),
                "order-matched item must NOT be auto-deleted")
        #expect(result.itemsToDelete.contains("promo"),
                "unmatched item follows entity autoDelete policy")
    }

    // MARK: protected entity

    @Test("protected entity prevents ALL auto-deletes regardless of retention policy")
    func protectedEntityPreventsDelete() {
        let now  = Date()
        // 30-day-old item — would normally be deleted by keepDays(7)
        let stale = ItemSnapshot(id: "stale", entityId: "e1",
                                 date: now.addingTimeInterval(-30 * 86400))
        let entity = EntitySnapshot(id: "e1",
                                    retentionPolicy: .keepDays(7),
                                    protectionLevel: .protected)
        let result = engine.evaluate(items: [stale], entity: entity, now: now)

        #expect(result.itemsToDelete.isEmpty,
                "protected entity: no items may be auto-deleted")
    }

    // MARK: importance pattern

    @Test("ImportancePattern elevates matching item to critical, leaves others nil")
    func importancePatternElevatesLevel() {
        let now = Date()
        let rateItem   = ItemSnapshot(id: "rate",   entityId: "e1", date: now,
                                      subject: "Your interest rates have changed")
        let normalItem = ItemSnapshot(id: "normal", entityId: "e1", date: now,
                                      subject: "Monthly newsletter digest")
        let pattern = ImportancePattern(matchType: .subjectContains,
                                        pattern: "rates",
                                        elevatedLevel: .critical)
        let entity = EntitySnapshot(id: "e1",
                                    retentionPolicy: .keepAll,
                                    importancePatterns: [pattern])
        let result = engine.evaluate(items: [rateItem, normalItem], entity: entity, now: now)

        #expect(result.elevatedImportance["rate"] == .critical,
                "matching item should be elevated to .critical")
        #expect(result.elevatedImportance["normal"] == nil,
                "non-matching item should have no elevation entry")
    }

    // MARK: highest pattern wins

    @Test("multiple patterns — highest level wins for an item matching both")
    func multiplePatternHighestWins() {
        let now = Date()
        let item = ItemSnapshot(id: "both", entityId: "e1", date: now,
                                subject: "Urgent rates security alert")
        let p1 = ImportancePattern(matchType: .subjectContains,
                                   pattern: "rates", elevatedLevel: .important)
        let p2 = ImportancePattern(matchType: .subjectContains,
                                   pattern: "Urgent", elevatedLevel: .critical)
        let entity = EntitySnapshot(id: "e1",
                                    retentionPolicy: .keepAll,
                                    importancePatterns: [p1, p2])
        let result = engine.evaluate(items: [item], entity: entity, now: now)

        #expect(result.elevatedImportance["both"] == .critical,
                "highest matching pattern level should win")
    }
}
