// Shared/PreviewData.swift
//
// Factory helpers for #Preview blocks.
// Requires Xcode — uses SwiftData @Model and SwiftUI previews.

import Foundation
import SwiftData
import Receptacle

/// Populates an in-memory `ModelContainer` with representative mock data.
///
/// Usage:
/// ```swift
/// #Preview {
///     EntityListView(selection: .constant(nil))
///         .modelContainer(PreviewData.container)
/// }
/// ```
@MainActor
enum PreviewData {

    static var container: ModelContainer = {
        let schema = Schema([
            Contact.self, Entity.self, EmailItem.self, FeedItem.self,
            AIPermission.self, Note.self, Tag.self, SavedLink.self,
            Project.self, KanbanColumn.self, TodoItem.self, SourceUsage.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext
        populate(context: ctx)
        return container
    }()

    // MARK: - Population

    private static func populate(context: ModelContext) {
        let now = Date()

        // --- Entities ---

        let mum = Entity(
            displayName: "Mum",
            importanceLevel: .important,
            protectionLevel: .protected,
            retentionPolicy: .keepAll,
            replyTone: .friendly
        )

        let amazon = Entity(
            displayName: "Amazon",
            importanceLevel: .normal,
            protectionLevel: .normal,
            retentionPolicy: .autoArchive,
            replyTone: .formal,
            subRules: [
                SubRule(matchType: .subjectContains, pattern: "Order", action: .keepAll),
            ]
        )

        let workTests = Entity(
            displayName: "Work Test Accounts",
            importanceLevel: .normal,
            protectionLevel: .apocalyptic,
            retentionPolicy: .keepDays(1),
            replyTone: .casualClean
        )

        let swiftBlog = Entity(
            displayName: "Swift.org Blog",
            importanceLevel: .normal,
            protectionLevel: .normal,
            retentionPolicy: .keepLatest(20),
            replyTone: .formal
        )

        let rates = Entity(
            displayName: "Bank Alerts",
            importanceLevel: .normal,
            importancePatterns: [
                ImportancePattern(
                    matchType: .subjectContains,
                    pattern: "rates",
                    elevatedLevel: .critical
                ),
            ],
            protectionLevel: .protected,
            retentionPolicy: .keepAll,
            replyTone: .formal
        )

        [mum, amazon, workTests, swiftBlog, rates].forEach { context.insert($0) }

        // --- Email items ---

        context.insert(EmailItem(
            id: "e1",
            entityId: mum.id.uuidString,
            sourceId: "imap-icloud",
            date: now.addingTimeInterval(-1_800),
            subject: "Dinner on Sunday?",
            fromAddress: "mum@example.com",
            fromName: "Mum",
            bodyPlain: "Hi love, are you free for dinner on Sunday? Let me know! Love, Mum"
        ))

        context.insert(EmailItem(
            id: "e2",
            entityId: mum.id.uuidString,
            sourceId: "imap-icloud",
            date: now.addingTimeInterval(-86_400 * 3),
            subject: "Re: Birthday plans",
            fromAddress: "mum@example.com",
            fromName: "Mum",
            bodyPlain: "That sounds lovely! Can't wait to see you. xxx"
        ))

        context.insert(EmailItem(
            id: "e3",
            entityId: amazon.id.uuidString,
            sourceId: "imap-gmail",
            date: now.addingTimeInterval(-3_600),
            subject: "Your Order #123-456 has shipped",
            fromAddress: "ship-confirm@amazon.co.uk",
            bodyHTML: "<b>Your order is on its way!</b><p>Expected by Friday.</p>"
        ))

        context.insert(EmailItem(
            id: "e4",
            entityId: amazon.id.uuidString,
            sourceId: "imap-gmail",
            date: now.addingTimeInterval(-86_400 * 7),
            subject: "Weekend deals just for you",
            fromAddress: "store-news@amazon.co.uk",
            bodyPlain: "Big savings this weekend. Don't miss out."
        ))

        context.insert(EmailItem(
            id: "e5",
            entityId: workTests.id.uuidString,
            sourceId: "imap-custom",
            date: now.addingTimeInterval(-7_200),
            subject: "Test run #42 results",
            fromAddress: "ci@work-tests.internal",
            bodyPlain: "All 312 tests passed. Build time: 4m 23s."
        ))

        context.insert(EmailItem(
            id: "e6",
            entityId: rates.id.uuidString,
            sourceId: "imap-icloud",
            date: now.addingTimeInterval(-600),
            subject: "Your savings rates have changed",
            fromAddress: "alerts@bank.example",
            bodyPlain: "Your ISA rate has changed from 4.5% to 4.2% effective 1 March."
        ))

        // --- Feed items ---

        context.insert(FeedItem(
            id: "f1",
            entityId: swiftBlog.id.uuidString,
            sourceId: "rss-swiftorg",
            date: now.addingTimeInterval(-43_200),
            title: "Swift 6.2 Released",
            contentHTML: "<p>The Swift team is pleased to announce Swift 6.2, featuring improved macros and a new standard library additions.</p>",
            linkURLString: "https://swift.org/blog/swift-6-2-released",
            authorName: "Swift Team",
            feedTitle: "Swift.org Blog"
        ))

        context.insert(FeedItem(
            id: "f2",
            entityId: swiftBlog.id.uuidString,
            sourceId: "rss-swiftorg",
            date: now.addingTimeInterval(-86_400 * 2),
            title: "Introducing the Swift Testing framework",
            contentHTML: "<p>Swift Testing is the modern replacement for XCTest, built into Swift 6.</p>",
            linkURLString: "https://swift.org/blog/swift-testing",
            authorName: "Swift Team",
            feedTitle: "Swift.org Blog"
        ))
    }
}
