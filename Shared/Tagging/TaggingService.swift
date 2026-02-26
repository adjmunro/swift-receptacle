import Foundation

// MARK: - TaggingService

/// Manages tag CRUD operations and AI-assisted tag suggestions.
///
/// Tags are cross-cutting — they apply to emails, feed articles, notes,
/// saved links, and todo items. AI suggestions are gated by `AIPermissionManager`.
actor TaggingService {
    private var allTags: [String: Tag] = [:]   // id → Tag
    private let permissionManager: AIPermissionManager
    private let aiProvider: any AIProvider

    init(
        tags: [Tag] = [],
        permissionManager: AIPermissionManager,
        aiProvider: any AIProvider
    ) {
        for tag in tags {
            allTags[tag.id.uuidString] = tag
        }
        self.permissionManager = permissionManager
        self.aiProvider = aiProvider
    }

    // MARK: - Tag CRUD

    func allTagsSorted() -> [Tag] {
        allTags.values.sorted { $0.name < $1.name }
    }

    func tag(id: String) -> Tag? {
        allTags[id]
    }

    func tag(named name: String) -> Tag? {
        allTags.values.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Returns all tags that have no parent (root tags)
    func rootTags() -> [Tag] {
        allTags.values.filter { $0.parentTagId == nil }.sorted { $0.name < $1.name }
    }

    /// Returns direct children of the given tag
    func children(of parentId: String) -> [Tag] {
        allTags.values.filter { $0.parentTagId == parentId }.sorted { $0.name < $1.name }
    }

    // MARK: - AI Suggestions

    /// Returns candidate tag names for the given text content.
    /// Returns [] immediately if permission is denied; throws on network/model error.
    func suggestTags(
        for text: String,
        entityId: String? = nil
    ) async throws -> [String] {
        let isDenied = await permissionManager.isDenied(
            providerId: aiProvider.providerId,
            feature: .tagSuggest,
            entityId: entityId
        )
        guard !isDenied else { return [] }

        return try await aiProvider.suggestTags(for: text)
    }
}
