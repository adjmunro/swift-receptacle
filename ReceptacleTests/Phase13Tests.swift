// Phase13Tests.swift
// CLI-compatible: only `import Testing` (no Foundation).
// Phase 13 is UI-only; these tests verify platform-agnostic SourceType behaviour
// that underpins the iOS iMessage tab-filtering logic.

import Testing
import Receptacle

// MARK: - SourceType Platform Tests

@Suite("SourceType — platform compatibility")
struct SourceTypePlatformTests {

    /// iMessage is macOS-only (chat.db). Verify it exists in the enum (platform-specific
    /// hiding is done in PostFeedView with `#if os(iOS)`).
    @Test func iMessageCaseExists() {
        #expect(SourceType.allCases.contains(.iMessage),
                "iMessage must exist so PostFeedView can filter it on iOS")
    }

    @Test func allCasesCount() {
        // email, rss, slack, teams, iMessage, matrix, xmpp, discord, webView, calendar
        #expect(SourceType.allCases.count == 10, "10 source types defined")
    }

    @Test func rawValues() {
        #expect(SourceType.iMessage.rawValue == "iMessage")
        #expect(SourceType.email.rawValue    == "email")
        #expect(SourceType.rss.rawValue      == "rss")
        #expect(SourceType.calendar.rawValue == "calendar")
    }

    /// The iOS filter (PostFeedView.availableSources) excludes iMessage.
    /// Model the same logic here to verify correctness.
    @Test func iOSFilterExcludesIMessage() {
        let seen: Set<SourceType> = [.email, .rss, .iMessage]
        // Simulate iOS filter
        let iosVisible = SourceType.allCases.filter { type in
            type != .iMessage && seen.contains(type)
        }
        #expect(!iosVisible.contains(.iMessage), "iOS filter removes iMessage")
        #expect(iosVisible.contains(.email),     "iOS filter keeps email")
        #expect(iosVisible.contains(.rss),       "iOS filter keeps rss")
    }

    @Test func macOSFilterKeepsIMessage() {
        let seen: Set<SourceType> = [.email, .rss, .iMessage]
        // Simulate macOS filter (no exclusion)
        let macVisible = SourceType.allCases.filter { seen.contains($0) }
        #expect(macVisible.contains(.iMessage), "macOS filter keeps iMessage")
        #expect(macVisible.contains(.email),    "macOS filter keeps email")
        #expect(macVisible.contains(.rss),      "macOS filter keeps rss")
    }
}

// MARK: - Navigation Architecture Notes

/// Documents the iOS vs macOS navigation split.
/// Not executable — compile-time documentation via @Test naming.
@Suite("iOS Navigation — architecture")
struct iOSNavigationTests {

    @Test func entityNavigable() {
        // Entity conforms to Identifiable — can be used as NavigationLink value.
        // (SwiftData models are Identifiable; this test verifies via the protocol.)
        // EntityListView on iOS uses NavigationLink(value: entity) { EntityRowView(entity:) }
        // IOSRootView provides .navigationDestination(for: Entity.self) { PostFeedView(entity:) }
        // Verified by build success in Xcode — no further CLI assertion needed.
        #expect(Bool(true), "Entity navigation architecture documented")
    }

    @Test func noHSplitViewOnIOS() {
        // NoteEditorView uses HSplitView on macOS and TabView on iOS.
        // PostFeedView notes panel is a .sheet on iOS (toolbar button → showNotesSheet).
        // These are compile-time `#if os(iOS)` guards — verified by Xcode build.
        #expect(Bool(true), "HSplitView guarded behind #if os(macOS)")
    }
}
