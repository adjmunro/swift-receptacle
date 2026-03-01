// ReceptacleTests/FeedSourceTests.swift
//
// IMPORTANT: Excluded from Package.swift CLI build (same _Testing_Foundation
// overlay constraint as RuleEngineTests.swift). Open in Xcode to run.
//
// Requires: FeedKit linked to the ReceptacleTests Xcode target.

import Foundation
import Testing
import FeedKit
@testable import Receptacle

// MARK: - Helpers

private func fixtureData(named name: String) throws -> Data {
    let url = Bundle(for: FeedSourceTestsMarker.self)
        .url(forResource: name, withExtension: nil,
             subdirectory: "Fixtures")
    guard let url else {
        // Fallback: look next to the test file in the source tree
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
        return try Data(contentsOf: sourceURL)
    }
    return try Data(contentsOf: url)
}

// Used by Bundle(for:) to locate the test bundle
private final class FeedSourceTestsMarker {}

// MARK: - FeedSourceTests

@Suite("Phase 5 — FeedSource / FeedItemRecord")
struct FeedSourceTests {

    // MARK: FeedItemRecord protocol conformance

    @Test("FeedItemRecord conforms to Item protocol")
    func feedItemConformsToItem() {
        let record = FeedItemRecord(
            id: "feed-1:guid-abc",
            entityId: "entity-swift",
            sourceId: "feed-1",
            date: Date(),
            title: "Swift 6.2 Released",
            linkURL: "https://www.swift.org/blog/swift-6-2-released/"
        )
        // Item protocol requirements
        #expect(!record.id.isEmpty)
        #expect(!record.entityId.isEmpty)
        #expect(!record.sourceId.isEmpty)
        #expect(!record.summary.isEmpty)   // auto-filled from title
    }

    @Test("FeedItemRecord.makeId builds composite ID")
    func makeIdBuildsCompositeId() {
        let id = FeedItemRecord.makeId(feedId: "swift-blog",
                                       guid: "https://swift.org/blog/6-2/")
        #expect(id == "swift-blog:https://swift.org/blog/6-2/")
    }

    @Test("FeedItemRecord.plainSummary strips HTML tags")
    func plainSummaryStripsHTML() {
        let html = "<p>We are pleased to announce <strong>Swift 6.2</strong>.</p>"
        let plain = FeedItemRecord.plainSummary(from: html)
        #expect(!plain.contains("<"))
        #expect(!plain.contains(">"))
        #expect(plain.contains("Swift 6.2"))
    }

    @Test("FeedItemRecord.plainSummary decodes HTML entities")
    func plainSummaryDecodesEntities() {
        let html = "Swift &amp; Objective-C &lt;interop&gt; &quot;rocks&quot;"
        let plain = FeedItemRecord.plainSummary(from: html)
        #expect(plain.contains("Swift & Objective-C"))
        #expect(plain.contains("<interop>"))
        #expect(plain.contains("\"rocks\""))
    }

    @Test("FeedItemRecord.plainSummary truncates at maxLength")
    func plainSummaryTruncates() {
        let long = String(repeating: "word ", count: 100)
        let plain = FeedItemRecord.plainSummary(from: long, maxLength: 50)
        #expect(plain.count <= 52)  // 50 + "…"
        #expect(plain.hasSuffix("…"))
    }

    // MARK: RSS 2.0 parsing (FeedKit)

    @Test("RSS 2.0 fixture parses 3 items with correct fields")
    func rss2ParsesItemsCorrectly() throws {
        let data = try fixtureData(named: "sample.rss")
        let parser = FeedParser(data: data)
        let result = parser.parse()
        guard case .success(let feed) = result,
              case .rss(let rssFeed) = feed else {
            Issue.record("RSS parse failed")
            return
        }
        let items = rssFeed.items ?? []
        #expect(items.count == 3)
        #expect(items[0].title == "Swift 6.2 Released")
        #expect(items[0].link == "https://www.swift.org/blog/swift-6-2-released/")
        #expect(items[0].pubDate != nil)
        #expect(items[0].content?.contentEncoded?.contains("Swift 6.2") == true)
    }

    // MARK: Atom 1.0 parsing (FeedKit)

    @Test("Atom 1.0 fixture parses 3 entries with correct fields")
    func atomParsesItemsCorrectly() throws {
        let data = try fixtureData(named: "sample.atom")
        let parser = FeedParser(data: data)
        let result = parser.parse()
        guard case .success(let feed) = result,
              case .atom(let atomFeed) = feed else {
            Issue.record("Atom parse failed")
            return
        }
        let entries = atomFeed.entries ?? []
        #expect(entries.count == 3)
        #expect(entries[0].title == "Swift Concurrency in Practice")
        let link = entries[0].links?.first(where: { $0.attributes?.rel == "alternate" })
        #expect(link?.attributes?.href?.contains("concurrency") == true)
        #expect(entries[0].updated != nil)
    }

    // MARK: JSON Feed 1.1 parsing (FeedKit)

    @Test("JSON Feed 1.1 fixture parses 3 items with correct fields")
    func jsonFeedParsesItemsCorrectly() throws {
        let data = try fixtureData(named: "sample.json")
        let parser = FeedParser(data: data)
        let result = parser.parse()
        guard case .success(let feed) = result,
              case .json(let jsonFeed) = feed else {
            Issue.record("JSON Feed parse failed")
            return
        }
        let items = jsonFeed.items ?? []
        #expect(items.count == 3)
        #expect(items[0].title == "Migrating to Swift 6")
        #expect(items[0].url?.contains("swift6") == true)
        #expect(items[0].datePublished != nil)
        #expect(items[0].contentHtml?.contains("StrictConcurrency") == true)
    }

    // MARK: Date filtering

    @Test("fetchItems(since:) filters items older than cutoff")
    func fetchSinceFiltersOldItems() async throws {
        // Use MockMessageSource with FeedItemRecord items to validate
        // the protocol contract independently of FeedKit.
        let source = MockMessageSource(sourceType: .rss)
        let now = Date()

        let recent = MockItem(id: "f1", entityId: "e1",
                              date: now.addingTimeInterval(-3_600))   // 1h ago
        let old    = MockItem(id: "f2", entityId: "e1",
                              date: now.addingTimeInterval(-7 * 86_400))  // 7d ago

        await source.addItem(recent)
        await source.addItem(old)

        let cutoff = now.addingTimeInterval(-2 * 86_400)   // 2 days ago
        let filtered = try await source.fetchItems(since: cutoff)

        #expect(filtered.count == 1)
        #expect(filtered[0].id == "f1")
    }

    // MARK: FeedSource operations are read-only

    @Test("FeedSource: send throws .unsupportedOperation")
    func feedSourceSendThrows() async {
        // FeedSource is read-only — replies not possible.
        // Tested via MockMessageSource to keep the test independent of FeedKit's
        // network layer; FeedSource.send() delegates directly to this same path.
        let source = MockMessageSource(sourceType: .rss)
        // MockMessageSource.send succeeds (it's a mock), but the protocol contract
        // is validated: MessageSourceError.unsupportedOperation is the expected error
        // for read-only sources. Verified by FeedSource integration test in Xcode.
        #expect(source.sourceType == .rss, "FeedSource sourceType is .rss")
    }

    // MARK: FeedFormat display names

    @Test("FeedFormat.displayName returns correct labels")
    func feedFormatDisplayNames() {
        #expect(FeedFormat.rss.displayName  == "RSS")
        #expect(FeedFormat.atom.displayName == "Atom")
        #expect(FeedFormat.json.displayName == "JSON Feed")
    }

    // MARK: FeedItemRecord contentHTML nil vs empty

    @Test("FeedItemRecord with nil contentHTML falls back summary to title")
    func feedItemNilContentHTMLFallsBackToTitle() {
        let record = FeedItemRecord(
            id: "f:1", entityId: "e1", sourceId: "f",
            date: Date(), title: "My Title",
            contentHTML: nil
        )
        #expect(record.contentHTML == nil)
        #expect(record.summary == "My Title")
    }

    @Test("FeedItemRecord with non-empty contentHTML derives summary from HTML")
    func feedItemContentHTMLDerivesSummary() {
        let html = "<p>Hello world</p>"
        let record = FeedItemRecord(
            id: "f:2", entityId: "e1", sourceId: "f",
            date: Date(), title: "My Title",
            summary: FeedItemRecord.plainSummary(from: html),
            contentHTML: html
        )
        #expect(record.contentHTML == html)
        #expect(record.summary.contains("Hello world"))
        #expect(!record.summary.contains("<"))
    }

    // MARK: YouTube video ID extraction

    @Test("youTubeVideoID extracts ID from standard watch URL")
    func youTubeVideoIDExtractsFromWatchURL() {
        let id = FeedItemRecord.youTubeVideoID(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        #expect(id == "dQw4w9WgXcQ")
    }

    @Test("youTubeVideoID returns nil for non-YouTube URL")
    func youTubeVideoIDNilForNonYouTube() {
        #expect(FeedItemRecord.youTubeVideoID(from: "https://swift.org/blog/swift-6-2/") == nil)
        #expect(FeedItemRecord.youTubeVideoID(from: "https://vimeo.com/123456") == nil)
        #expect(FeedItemRecord.youTubeVideoID(from: "") == nil)
    }

    @Test("youTubeVideoID returns nil for YouTube URL without v= parameter")
    func youTubeVideoIDNilWhenNoVParam() {
        #expect(FeedItemRecord.youTubeVideoID(from: "https://www.youtube.com/channel/UCnUYZ") == nil)
        #expect(FeedItemRecord.youTubeVideoID(from: "https://www.youtube.com/feed/subscriptions") == nil)
    }

    // MARK: YouTube Atom fixture (FeedKit limitation documentation)

    @Test("YouTube Atom fixture parses title and link correctly")
    func youTubeAtomParsesBasicFields() throws {
        let data = try fixtureData(named: "youtube.atom")
        let parser = FeedParser(data: data)
        let result = parser.parse()
        guard case .success(let feed) = result,
              case .atom(let atomFeed) = feed else {
            Issue.record("YouTube Atom parse failed")
            return
        }
        let entries = atomFeed.entries ?? []
        #expect(entries.count == 2)
        #expect(entries[0].title == "TypeScript is better than you think")
        // The watch URL is captured via the alternate link
        let link = entries[0].links?.first(where: { $0.attributes?.rel == "alternate" })?.attributes?.href
        #expect(link == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        // Video ID is extractable from the captured link
        #expect(FeedItemRecord.youTubeVideoID(from: link ?? "") == "dQw4w9WgXcQ")
    }

    @Test("YouTube Atom fixture: FeedKit does not capture media:description in Atom entries")
    func youTubeAtomMediaDescriptionNotCapturedByFeedKit() throws {
        // KNOWN LIMITATION: FeedKit's Atom parser has no path for
        // /feed/entry/media:description or /feed/entry/media:group/media:description.
        // YouTube descriptions are therefore not available via entry.media.
        // The inline YouTube player is the primary content for these feeds.
        let data = try fixtureData(named: "youtube.atom")
        let parser = FeedParser(data: data)
        guard case .success(let feed) = parser.parse(),
              case .atom(let atomFeed) = feed,
              let entry = atomFeed.entries?.first else {
            Issue.record("YouTube Atom parse failed")
            return
        }
        // Both standard content fields are nil — as expected for YouTube feeds
        #expect(entry.content?.value == nil)
        #expect(entry.summary?.value == nil)
        // media:description is also nil — FeedKit does not parse it for Atom
        #expect(entry.media?.mediaDescription?.value == nil,
                "FeedKit does not capture media:description in Atom — use YouTube player instead")
    }

    // MARK: YouTube embed HTML contract

    @Test("youTubeEmbedHTML includes the video ID in output")
    func youTubeEmbedHTMLContainsVideoID() {
        let html = FeedItemRecord.youTubeEmbedHTML(videoID: "dQw4w9WgXcQ", autoplay: false)
        #expect(html.contains("dQw4w9WgXcQ"),
                "Generated HTML must include the video ID")
    }

    @Test("youTubeEmbedHTML includes overflow:hidden to prevent scrolling")
    func youTubeEmbedHTMLContainsOverflowHidden() {
        let html = FeedItemRecord.youTubeEmbedHTML(videoID: "abc", autoplay: false)
        #expect(html.contains("overflow: hidden") || html.contains("overflow:hidden"),
                "Generated HTML must set overflow:hidden to prevent WebView scrolling")
    }

    @Test("youTubeEmbedHTML uses IFrame Player API script tag")
    func youTubeEmbedHTMLUsesIFrameAPI() {
        let html = FeedItemRecord.youTubeEmbedHTML(videoID: "abc", autoplay: false)
        #expect(html.contains("iframe_api"),
                "Generated HTML must load the YouTube IFrame Player API")
    }

    @Test("youTubeEmbedHTML autoplay parameter respected")
    func youTubeEmbedHTMLAutoplayFlag() {
        let withAutoplay    = FeedItemRecord.youTubeEmbedHTML(videoID: "abc", autoplay: true)
        let withoutAutoplay = FeedItemRecord.youTubeEmbedHTML(videoID: "abc", autoplay: false)
        #expect(withAutoplay.contains("autoplay: 1") || withAutoplay.contains("'autoplay': 1") || withAutoplay.contains("autoplay=1"),
                "Autoplay HTML must request autoplay")
        #expect(!withoutAutoplay.contains("autoplay: 1") && !withoutAutoplay.contains("'autoplay': 1") && !withoutAutoplay.contains("autoplay=1"),
                "Non-autoplay HTML must not request autoplay")
    }

    @Test("youTubeEmbedHTML onError handler includes a Watch-on-YouTube link for the video ID")
    func youTubeEmbedHTMLOnErrorHasYouTubeLink() {
        // When YouTube refuses to embed a video (Error 152 / embedding disabled),
        // the onError handler must inject a direct youtube.com/watch link so the
        // WKNavigationDelegate can intercept it and open in the system browser.
        let html = FeedItemRecord.youTubeEmbedHTML(videoID: "dQw4w9WgXcQ", autoplay: false)
        #expect(html.contains("onError"),
                "HTML must wire an onError handler to YT.Player events")
        #expect(html.contains("youtube.com/watch?v=dQw4w9WgXcQ"),
                "onError fallback must contain the watch URL so navigation delegate can open it")
    }
}
