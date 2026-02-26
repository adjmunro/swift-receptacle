import Foundation

// MARK: - NoteRevisionRecord

/// A full snapshot of a note's Markdown content before an edit.
///
/// Stored in `NoteRecord.revisionHistory` (oldest first).
/// Used for rollback: restoring a revision replaces `markdownContent` with
/// the snapshot and marks `updatedAt`.
public struct NoteRevisionRecord: Sendable {
    /// When this revision was captured.
    public var timestamp: Date
    /// Full Markdown content at the time of capture.
    public var content: String
    /// Human-readable label: "AI summarise", "Manual edit", etc.
    public var changeDescription: String?

    public init(
        timestamp: Date = Date(),
        content: String,
        changeDescription: String? = nil
    ) {
        self.timestamp = timestamp
        self.content = content
        self.changeDescription = changeDescription
    }
}

// MARK: - NoteRecord

/// Pure-Swift value-type representation of a Markdown note.
///
/// Mirrors the `Note` SwiftData `@Model` in `Shared/Models/Note.swift` for CLI testing.
///
/// ## Key operations
/// - `pushRevision(changeDescription:)` — snapshot current content BEFORE any AI edit
/// - `appendSummary(_:)` — APPEND an AI-generated summary; never replaces existing content
/// - `restoreRevision(at:)` — revert to a historical snapshot
/// - `updateLinkedNoteIds(using:allNotes:)` — resolve `[[wikilinks]]` to note IDs
///
/// ## Append-not-replace invariant
/// AI summarise MUST call `pushRevision` first, then `appendSummary`.
/// This preserves the user's text and allows rollback:
/// ```swift
/// note.pushRevision(changeDescription: "AI summarise")
/// note.appendSummary(summaryText)
/// ```
public struct NoteRecord: Identifiable, Sendable {

    public var id: String
    public var title: String
    /// Raw Markdown with optional `[[wikilink]]` syntax.
    public var markdownContent: String
    public var createdAt: Date
    public var updatedAt: Date
    public var tagIds: [String]
    /// IDs of inbox items (email, feed, etc.) this note is linked to.
    public var linkedItemIds: [String]
    /// IDs of other notes referenced via `[[wikilinks]]` (resolved).
    public var linkedNoteIds: [String]
    /// Ordered snapshots — oldest first. The most recent is `revisionHistory.last`.
    public var revisionHistory: [NoteRevisionRecord]

    public init(
        id: String = UUID().uuidString,
        title: String,
        markdownContent: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tagIds: [String] = [],
        linkedItemIds: [String] = [],
        linkedNoteIds: [String] = []
    ) {
        self.id = id
        self.title = title
        self.markdownContent = markdownContent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tagIds = tagIds
        self.linkedItemIds = linkedItemIds
        self.linkedNoteIds = linkedNoteIds
        self.revisionHistory = []
    }

    // MARK: - Revision management

    /// Capture the current `markdownContent` as a revision BEFORE a destructive edit.
    ///
    /// Call this immediately before any AI edit or content replacement.
    public mutating func pushRevision(changeDescription: String? = nil) {
        revisionHistory.append(
            NoteRevisionRecord(
                content: markdownContent,
                changeDescription: changeDescription
            )
        )
        updatedAt = Date()
    }

    /// Restore content from a historical revision by zero-based index.
    ///
    /// Revision history is preserved — restoring does NOT truncate it.
    /// Returns `false` if `index` is out of bounds.
    @discardableResult
    public mutating func restoreRevision(at index: Int) -> Bool {
        guard index >= 0, index < revisionHistory.count else { return false }
        markdownContent = revisionHistory[index].content
        updatedAt = Date()
        return true
    }

    // MARK: - AI summarise → append

    /// Append an AI summary to the note content.
    ///
    /// **Never replaces existing content.**
    /// Always call `pushRevision` before this so the pre-summary state is recoverable.
    ///
    /// - Parameter summary: The AI-generated summary text.
    public mutating func appendSummary(_ summary: String) {
        let separator = markdownContent.isEmpty ? "" : "\n\n---\n"
        markdownContent += "\(separator)**AI Summary**\n\(summary)"
        updatedAt = Date()
    }

    // MARK: - Wikilink resolution

    /// Resolve `[[wikilinks]]` in this note's content against a list of known notes.
    ///
    /// Updates `linkedNoteIds` in place.
    ///
    /// - Parameters:
    ///   - parser: A `WikilinkParser` instance.
    ///   - allNotes: Flat list of `(id, title)` pairs from the note store.
    public mutating func updateLinkedNoteIds(
        using parser: WikilinkParser,
        allNotes: [(id: String, title: String)]
    ) {
        let result = parser.resolve(markdown: markdownContent) { target in
            allNotes.first { $0.title.caseInsensitiveCompare(target) == .orderedSame }?.id
        }
        linkedNoteIds = Array(result.resolvedIds.values)
        updatedAt = Date()
    }
}
