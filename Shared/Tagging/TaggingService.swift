import Foundation
import Receptacle  // TagRecord, TagService, AIProvider, AIGate

// MARK: - TaggingService (SwiftData-backed facade)

/// SwiftData-backed tagging facade.
///
/// Wraps `TagService` (in ReceptacleCore) with persistence to `Tag` SwiftData models.
/// All pure logic (hierarchy, association, AI suggestions) lives in `TagService`;
/// this actor bridges it with the SwiftData context used by the UI layer.
///
/// ## Usage (Phase 10+):
/// ```swift
/// let service = TaggingService(
///     modelContext: modelContext,
///     aiProvider: claudeProvider,
///     gate: AIGate.shared,
///     providerId: "claude"
/// )
///
/// // Add a tag
/// try await service.createTag(name: "Swift", parentTagId: nil)
///
/// // AI suggestion
/// let candidates = try await service.suggestTags(for: emailBody, entityId: entity.id)
/// // Show candidates as dismissable chips in PostCardView
/// ```
public actor TaggingService {

    private let core: TagService

    // SwiftData ModelContext would be injected here (Xcode phase):
    // private let modelContext: ModelContext

    init(
        aiProvider: any AIProvider,
        gate: AIGate,
        providerId: String
    ) {
        self.core = TagService(aiProvider: aiProvider, gate: gate, providerId: providerId)
    }

    // MARK: - Tag CRUD

    /// Create a new tag and persist it to SwiftData.
    ///
    /// ```swift
    /// // Phase 10 — uncomment when ModelContext is injected:
    /// // let tag = Tag(name: name, parentTagId: parentTagId, colorHex: colorHex)
    /// // modelContext.insert(tag)
    /// // try modelContext.save()
    /// ```
    public func createTag(
        name: String,
        parentTagId: String? = nil,
        colorHex: String? = nil
    ) async {
        let record = TagRecord(name: name, parentTagId: parentTagId, colorHex: colorHex)
        await core.add(tag: record)
    }

    /// Hierarchical display path for a tag (e.g. `"Work/Projects/Receptacle"`).
    public func path(for tagId: String) async -> String {
        await core.path(for: tagId)
    }

    /// All root tags (no parent), sorted by name.
    public func rootTags() async -> [TagRecord] {
        await core.rootTags()
    }

    /// Direct children of a given parent, sorted by name.
    public func children(of parentId: String) async -> [TagRecord] {
        await core.children(of: parentId)
    }

    /// Associate a tag with any item ID (type-agnostic).
    public func addTag(_ tagId: String, toItemId itemId: String) async {
        await core.addTag(tagId, toItemId: itemId)
    }

    /// All item IDs associated with a given tag.
    public func itemIds(forTagId tagId: String) async -> Set<String> {
        await core.itemIds(forTagId: tagId)
    }

    // MARK: - AI Suggestions

    /// Returns candidate tag names for the given text. Returns `[]` if permission denied.
    public func suggestTags(for text: String, entityId: String? = nil) async throws -> [String] {
        try await core.suggestTags(for: text, entityId: entityId)
    }
}
