import Foundation
import SwiftData

/// A single article or entry from an RSS/Atom/JSON Feed source.
///
/// Conforms to the `Item` protocol so it flows through the same inbox as email.
@Model
final class FeedItem {
    /// Stable identifier: feed URL + article GUID composite key
    var id: String
    var entityId: String
    var sourceId: String
    var date: Date

    var title: String
    var contentHTML: String?
    var linkURLString: String?
    var authorName: String?
    var feedTitle: String?

    var isRead: Bool
    var isSaved: Bool

    /// AI-generated one-sentence summary (cached after first generation)
    var aiSummary: String?

    var tagIds: [String]

    init(
        id: String,
        entityId: String,
        sourceId: String,
        date: Date,
        title: String,
        contentHTML: String? = nil,
        linkURLString: String? = nil,
        authorName: String? = nil,
        feedTitle: String? = nil
    ) {
        self.id = id
        self.entityId = entityId
        self.sourceId = sourceId
        self.date = date
        self.title = title
        self.contentHTML = contentHTML
        self.linkURLString = linkURLString
        self.authorName = authorName
        self.feedTitle = feedTitle
        self.isRead = false
        self.isSaved = false
        self.tagIds = []
    }

    var summary: String {
        if let html = contentHTML {
            let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            return String(stripped.prefix(150))
        }
        return title
    }
}

extension FeedItem: Item {
    // Explicit conformance provided by the stored properties above
}
