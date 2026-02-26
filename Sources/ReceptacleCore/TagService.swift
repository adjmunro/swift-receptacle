// MARK: - TagService

/// In-memory tag store with hierarchy resolution, cross-source association, and
/// AI-gated tag suggestions.
///
/// Used directly in CLI tests (with `MockAIProvider`).
/// The SwiftData-backed `TaggingService` in `Shared/Tagging/TaggingService.swift`
/// wraps this logic with persistence.
///
/// ## Tag Hierarchy
/// Tags form a tree via `parentTagId`. `path(for:)` resolves the full display path:
/// ```
/// let work = TagRecord(name: "Work")
/// let proj = TagRecord(name: "Projects", parentTagId: work.id)
/// let rec  = TagRecord(name: "Receptacle", parentTagId: proj.id)
/// // service.path(for: rec.id) == "Work/Projects/Receptacle"
/// ```
///
/// ## Cross-Source Association
/// Any item (email, RSS, note, saved link, todo) is associated by its `itemId` string.
/// The service is item-type-agnostic — it stores `tagId → Set<itemId>` mappings.
///
/// ## AI Suggestions
/// `suggestTags(for:providerId:entityId:)` is gated by `AIGate` with `.tagSuggest`
/// feature. Returns `[]` immediately if permission is `.never`.
public actor TagService {

    private var tags: [String: TagRecord] = [:]          // id → TagRecord
    private var associations: [String: Set<String>] = [:] // tagId → Set<itemId>

    private let aiProvider: any AIProvider
    private let gate: AIGate
    private let providerId: String

    public init(
        aiProvider: any AIProvider,
        gate: AIGate,
        providerId: String
    ) {
        self.aiProvider = aiProvider
        self.gate = gate
        self.providerId = providerId
    }

    // MARK: - Tag CRUD

    /// Add or replace a tag. Returns the stored record.
    public func add(tag: TagRecord) {
        tags[tag.id] = tag
    }

    /// Remove a tag and all its associations.
    public func remove(tagId: String) {
        tags.removeValue(forKey: tagId)
        associations.removeValue(forKey: tagId)
    }

    /// Look up a tag by ID.
    public func tag(id: String) -> TagRecord? { tags[id] }

    /// Find the first tag with the given name (case-insensitive).
    public func tag(named name: String) -> TagRecord? {
        tags.values.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// All tags sorted by name.
    public func allTags() -> [TagRecord] {
        tags.values.sorted { $0.name < $1.name }
    }

    /// Root tags (no parent), sorted by name.
    public func rootTags() -> [TagRecord] {
        tags.values.filter { $0.parentTagId == nil }.sorted { $0.name < $1.name }
    }

    /// Direct children of a given parent tag ID, sorted by name.
    public func children(of parentId: String) -> [TagRecord] {
        tags.values.filter { $0.parentTagId == parentId }.sorted { $0.name < $1.name }
    }

    /// Full hierarchical display path for a tag (e.g. `"Work/Projects/Receptacle"`).
    ///
    /// Traversal is limited to 10 levels to guard against accidental cycles.
    public func path(for tagId: String) -> String {
        var parts: [String] = []
        var currentId: String? = tagId
        var depth = 0
        while let id = currentId, depth < 10 {
            guard let tag = tags[id] else { break }
            parts.insert(tag.name, at: 0)
            currentId = tag.parentTagId
            depth += 1
        }
        return parts.joined(separator: "/")
    }

    // MARK: - Cross-Source Association

    /// Associate a tag with an item (by item ID string, type-agnostic).
    public func addTag(_ tagId: String, toItemId itemId: String) {
        associations[tagId, default: []].insert(itemId)
    }

    /// Remove the association between a tag and an item.
    public func removeTag(_ tagId: String, fromItemId itemId: String) {
        associations[tagId]?.remove(itemId)
    }

    /// All item IDs associated with the given tag ID.
    public func itemIds(forTagId tagId: String) -> Set<String> {
        associations[tagId] ?? []
    }

    /// All tag IDs associated with the given item ID.
    public func tagIds(forItemId itemId: String) -> [String] {
        associations.compactMap { tagId, items in
            items.contains(itemId) ? tagId : nil
        }.sorted()
    }

    // MARK: - AI Suggestions

    /// Returns candidate tag names for the given text content.
    ///
    /// Returns `[]` immediately if the `.tagSuggest` permission is `.never`.
    /// Throws `AIProviderError.permissionDenied` is not thrown — the gate returns
    /// `[]` on denial so callers don't need to handle that case specially.
    public func suggestTags(
        for text: String,
        entityId: String? = nil
    ) async throws -> [String] {
        let isBlocked = await gate.isBlocked(
            providerId: providerId,
            feature: .tagSuggest,
            entityId: entityId
        )
        guard !isBlocked else { return [] }

        let provider = aiProvider
        return try await gate.perform(
            providerId: providerId,
            feature: .tagSuggest,
            entityId: entityId
        ) {
            try await provider.suggestTags(for: text)
        }
    }
}
