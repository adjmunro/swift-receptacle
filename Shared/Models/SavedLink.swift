import Foundation
import SwiftData

/// A bookmarked URL that persists independently of its source item.
///
/// When a user bookmarks a link from an email or feed article, a `SavedLink` is
/// created. The source item can later be deleted (per retention policy) without
/// losing the saved link.
@Model
final class SavedLink {
    var id: UUID
    var urlString: String
    var title: String?
    /// The item it was saved from — may be nil if the source item was deleted
    var sourceItemId: String?
    var savedAt: Date
    var tagIds: [String]
    var notes: String?

    init(
        urlString: String,
        title: String? = nil,
        sourceItemId: String? = nil,
        tagIds: [String] = [],
        notes: String? = nil
    ) {
        self.id = UUID()
        self.urlString = urlString
        self.title = title
        self.sourceItemId = sourceItemId
        self.savedAt = Date()
        self.tagIds = tagIds
        self.notes = notes
    }
}
