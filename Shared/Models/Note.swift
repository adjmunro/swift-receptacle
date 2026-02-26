import Foundation
import SwiftData

// MARK: - Note Revision

/// A full snapshot of a note's content before a change.
/// Used for AI edit rollback.
struct NoteRevision: Codable, Sendable {
    var timestamp: Date
    /// Full Markdown content before this revision
    var content: String
    /// Human-readable description: "AI summarise", "AI reframe", "manual edit"
    var changeDescription: String?
}

// MARK: - Note

/// A Markdown note that can be linked to inbox items and other notes
/// via `[[wikilink]]` syntax.
@Model
final class Note {
    var id: UUID
    var title: String
    /// Raw Markdown with optional [[wikilink]] extensions
    var markdownContent: String
    var createdAt: Date
    var updatedAt: Date
    var tagIds: [String]
    /// IDs of inbox items (email, feed, etc.) this note is linked to
    var linkedItemIds: [String]
    /// IDs of other notes this note links to (resolved from [[wikilinks]])
    var linkedNoteIds: [String]
    /// Ordered snapshots; most recent last. Used for AI-edit rollback.
    var revisionHistory: [NoteRevision]

    init(title: String, markdownContent: String = "") {
        self.id = UUID()
        self.title = title
        self.markdownContent = markdownContent
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tagIds = []
        self.linkedItemIds = []
        self.linkedNoteIds = []
        self.revisionHistory = []
    }

    /// Saves a snapshot of the current content before a destructive edit.
    func pushRevision(changeDescription: String? = nil) {
        let rev = NoteRevision(
            timestamp: Date(),
            content: markdownContent,
            changeDescription: changeDescription
        )
        revisionHistory.append(rev)
        updatedAt = Date()
    }
}
