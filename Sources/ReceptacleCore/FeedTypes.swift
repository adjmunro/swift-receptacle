import Foundation

// MARK: - FeedFormat

/// The wire format of an RSS/Atom/JSON Feed.
public enum FeedFormat: String, Codable, CaseIterable, Sendable {
    case rss    // RSS 2.0
    case atom   // Atom 1.0
    case json   // JSON Feed 1.1
}

// MARK: - FeedConfig

/// Configuration for a single RSS/Atom/JSON Feed source.
///
/// Each feed URL maps to a `Contact` (type: .feed) + `Entity` in SwiftData.
/// The same rules, importance, and retention policies apply as for email entities.
public struct FeedConfig: Codable, Sendable {
    public var feedId: String
    public var displayName: String
    public var feedURLString: String
    public var entityId: String

    public init(feedId: String,
                displayName: String,
                feedURLString: String,
                entityId: String) {
        self.feedId = feedId
        self.displayName = displayName
        self.feedURLString = feedURLString
        self.entityId = entityId
    }
}

// MARK: - FeedItemRecord

/// Value-type mirror of the SwiftData `FeedItem` @Model.
///
/// Produced by `FeedSource.fetchItems(since:)` and usable in CLI tests
/// without importing SwiftData. Conforms to the `Item` protocol so it
/// slots into the shared `RuleEngine`, `MockMessageSource`, etc.
public struct FeedItemRecord: Item, Sendable {

    // MARK: Item
    public var id: String        // "<feedId>:<itemGuid>"
    public var entityId: String
    public var sourceId: String
    public var date: Date
    public var summary: String   // First 200 chars of content, plain-text

    // MARK: Feed-specific
    public var title: String
    public var linkURL: String?
    public var contentHTML: String?
    public var format: FeedFormat

    public init(
        id: String,
        entityId: String,
        sourceId: String,
        date: Date = Date(),
        title: String,
        summary: String = "",
        linkURL: String? = nil,
        contentHTML: String? = nil,
        format: FeedFormat = .rss
    ) {
        self.id = id
        self.entityId = entityId
        self.sourceId = sourceId
        self.date = date
        self.title = title
        self.summary = summary.isEmpty ? String(title.prefix(200)) : summary
        self.linkURL = linkURL
        self.contentHTML = contentHTML
        self.format = format
    }
}

// MARK: - FeedItemRecord factory helpers

extension FeedItemRecord {

    /// Builds the composite ID from a feed ID and an item GUID.
    public static func makeId(feedId: String, guid: String) -> String {
        "\(feedId):\(guid)"
    }

    /// Extracts a plain-text summary from HTML content (strips tags, trims).
    public static func plainSummary(from html: String, maxLength: Int = 200) -> String {
        // Minimal tag stripper — replace tags with spaces, collapse whitespace.
        // Good enough for preview text; full HTML rendering happens in WebView.
        var result = html
        // Replace common block tags with newlines
        for tag in ["</p>", "<br>", "<br/>", "<br />", "</li>", "</h1>",
                    "</h2>", "</h3>", "</h4>"] {
            result = result.replacingOccurrences(of: tag, with: " ")
        }
        // Strip remaining tags
        while let start = result.range(of: "<"),
              let end = result.range(of: ">", range: start.upperBound..<result.endIndex) {
            result.removeSubrange(start.lowerBound..<end.upperBound)
        }
        // Collapse whitespace and decode common entities
        result = result
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
        // Normalise whitespace
        let words = result.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let joined = words.joined(separator: " ")
        return joined.count <= maxLength ? joined : String(joined.prefix(maxLength)) + "…"
    }
}
