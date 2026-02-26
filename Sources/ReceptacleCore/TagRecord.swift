import Foundation

// MARK: - TagRecord

/// Pure-Swift value-type representation of a tag.
///
/// Mirrors the `Tag` SwiftData `@Model` in `Shared/Models/Tag.swift` for CLI testing.
/// Cross-cutting: applied to emails, RSS articles, notes, saved links, and todo items.
///
/// Hierarchy: `parentTagId` enables tree structure (e.g. "Work" → "Work/Projects").
/// Full path resolution is provided by `TagService.path(for:)`.
public struct TagRecord: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var parentTagId: String?
    /// Hex colour string (e.g. `"#FF5733"`), or `nil` for the system default.
    public var colorHex: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        parentTagId: String? = nil,
        colorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.parentTagId = parentTagId
        self.colorHex = colorHex
    }
}

// MARK: - SavedLinkRecord

/// Pure-Swift value-type representation of a bookmarked URL.
///
/// Mirrors the `SavedLink` SwiftData `@Model` in `Shared/Models/SavedLink.swift`.
///
/// The key invariant: `sourceItemId` is **nullable**. When the source item is deleted
/// (per a retention policy), `sourceItemId` is set to `nil` — but the `SavedLinkRecord`
/// itself is never deleted. This is the "persists after source deleted" guarantee.
public struct SavedLinkRecord: Identifiable, Sendable {
    public var id: String
    public var urlString: String
    public var title: String?
    /// The item this link was saved from. `nil` if the source has since been deleted.
    public var sourceItemId: String?
    public var savedAt: Date
    public var tagIds: [String]
    public var notes: String?

    /// `true` when the source item no longer exists (was deleted).
    public var isOrphaned: Bool { sourceItemId == nil }

    public init(
        id: String = UUID().uuidString,
        urlString: String,
        title: String? = nil,
        sourceItemId: String? = nil,
        savedAt: Date = Date(),
        tagIds: [String] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.sourceItemId = sourceItemId
        self.savedAt = savedAt
        self.tagIds = tagIds
        self.notes = notes
    }

    /// Produce a copy with `sourceItemId` cleared (call when the source item is deleted).
    public func orphaned() -> SavedLinkRecord {
        var copy = self
        copy.sourceItemId = nil
        return copy
    }
}
