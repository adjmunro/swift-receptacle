// TaggingTests.swift
// CLI-compatible: only `import Testing` (no Foundation).
// Run via: swift test  (or open in Xcode for full output)

import Testing
import Receptacle

// MARK: - Helpers

private func makeTagService(scope: AIScope = .always) async -> TagService {
    let mockAI = MockAIProvider()
    let manager = AIPermissionManager()
    await manager.set(scope: scope, providerId: "mock-ai", feature: .tagSuggest)
    let gate = AIGate(permissionManager: manager)
    return TagService(aiProvider: mockAI, gate: gate, providerId: "mock-ai")
}

// MARK: - TagRecord Tests

@Suite("TagRecord")
struct TagRecordTests {

    @Test func tagRecord_basicProperties() {
        let tag = TagRecord(id: "t1", name: "Swift", colorHex: "#FF5733")
        #expect(tag.id == "t1")
        #expect(tag.name == "Swift")
        #expect(tag.parentTagId == nil)
        #expect(tag.colorHex == "#FF5733")
    }

    @Test func tagRecord_withParent() {
        let parent = TagRecord(name: "Work")
        let child  = TagRecord(name: "Projects", parentTagId: parent.id)
        #expect(child.parentTagId == parent.id)
    }
}

// MARK: - TagService: Hierarchy Tests

@Suite("TagService — hierarchy")
struct TagServiceHierarchyTests {

    @Test func test_tagHierarchy_parentChildRelationship() async {
        let service = await makeTagService()

        let work     = TagRecord(id: "work",     name: "Work")
        let projects = TagRecord(id: "projects", name: "Projects",   parentTagId: "work")
        let recep    = TagRecord(id: "recep",    name: "Receptacle", parentTagId: "projects")

        await service.add(tag: work)
        await service.add(tag: projects)
        await service.add(tag: recep)

        // rootTags returns only top-level tags
        let roots = await service.rootTags()
        #expect(roots.count == 1)
        #expect(roots[0].id == "work")

        // children(of:) returns direct children only
        let workChildren = await service.children(of: "work")
        #expect(workChildren.count == 1)
        #expect(workChildren[0].id == "projects")

        let projChildren = await service.children(of: "projects")
        #expect(projChildren.count == 1)
        #expect(projChildren[0].id == "recep")

        let leafChildren = await service.children(of: "recep")
        #expect(leafChildren.isEmpty, "leaf node has no children")

        // path(for:) resolves full hierarchy
        let rootPath = await service.path(for: "work")
        #expect(rootPath == "Work")

        let midPath = await service.path(for: "projects")
        #expect(midPath == "Work/Projects")

        let leafPath = await service.path(for: "recep")
        #expect(leafPath == "Work/Projects/Receptacle")
    }

    @Test func test_tagHierarchy_multipleRoots() async {
        let service = await makeTagService()
        await service.add(tag: TagRecord(id: "a", name: "Apple"))
        await service.add(tag: TagRecord(id: "b", name: "Banana"))
        await service.add(tag: TagRecord(id: "c", name: "Cherry", parentTagId: "a"))

        let roots = await service.rootTags()
        #expect(roots.count == 2, "two root tags")
        #expect(roots.map(\.name).contains("Apple"))
        #expect(roots.map(\.name).contains("Banana"))
    }

    @Test func test_tagHierarchy_removePreservesOthers() async {
        let service = await makeTagService()
        await service.add(tag: TagRecord(id: "x", name: "X"))
        await service.add(tag: TagRecord(id: "y", name: "Y"))
        await service.remove(tagId: "x")

        let all = await service.allTags()
        #expect(all.count == 1)
        #expect(all[0].id == "y")
    }
}

// MARK: - TagService: AI Suggestion Tests

@Suite("TagService — AI suggestion gating")
struct TagServiceSuggestionTests {

    @Test func test_tagSuggestion_gatedByAIPermission_allowed() async throws {
        let mockAI = MockAIProvider()
        await mockAI.set(suggestTagsResult: ["swift", "ios", "wwdc"])
        let manager = AIPermissionManager()
        await manager.set(scope: .always, providerId: "mock-ai", feature: .tagSuggest)
        let gate = AIGate(permissionManager: manager)
        let service = TagService(aiProvider: mockAI, gate: gate, providerId: "mock-ai")

        let suggestions = try await service.suggestTags(for: "WWDC session about Swift macros")
        #expect(suggestions == ["swift", "ios", "wwdc"])

        let callCount = await mockAI.suggestTagsCalled
        #expect(callCount == 1)
    }

    @Test func test_tagSuggestion_gatedByAIPermission_denied() async throws {
        let mockAI = MockAIProvider()
        await mockAI.set(suggestTagsResult: ["should-not-appear"])
        let manager = AIPermissionManager()
        await manager.set(scope: .never, providerId: "mock-ai", feature: .tagSuggest)
        let gate = AIGate(permissionManager: manager)
        let service = TagService(aiProvider: mockAI, gate: gate, providerId: "mock-ai")

        let suggestions = try await service.suggestTags(for: "some content")
        #expect(suggestions.isEmpty, "denied permission returns [] without calling AI")

        let callCount = await mockAI.suggestTagsCalled
        #expect(callCount == 0, "AI provider never called when permission is .never")
    }

    @Test func test_tagSuggestion_entityOverride() async throws {
        let mockAI = MockAIProvider()
        await mockAI.set(suggestTagsResult: ["tag1"])
        let manager = AIPermissionManager()
        await manager.set(scope: .always, providerId: "mock-ai", feature: .tagSuggest)
        await manager.set(scope: .never,  providerId: "mock-ai", feature: .tagSuggest, entityId: "private-entity")
        let gate = AIGate(permissionManager: manager)
        let service = TagService(aiProvider: mockAI, gate: gate, providerId: "mock-ai")

        let globalOK = try await service.suggestTags(for: "content")
        #expect(globalOK == ["tag1"], "global .always proceeds")

        let entityBlocked = try await service.suggestTags(for: "content", entityId: "private-entity")
        #expect(entityBlocked.isEmpty, "entity .never returns []")
    }
}

// MARK: - TagService: Cross-Source Association Tests

@Suite("TagService — cross-source filtering")
struct TagServiceAssociationTests {

    @Test func test_tagBrowser_filtersAcrossAllItemTypes() async {
        let service = await makeTagService()

        let swift = TagRecord(id: "swift", name: "swift")
        let ios   = TagRecord(id: "ios",   name: "ios")
        await service.add(tag: swift)
        await service.add(tag: ios)

        // Associate the "swift" tag with items of different types
        await service.addTag("swift", toItemId: "email-1")       // email
        await service.addTag("swift", toItemId: "feed-article-1") // RSS
        await service.addTag("swift", toItemId: "note-1")         // note
        await service.addTag("swift", toItemId: "link-1")         // saved link
        // todo-1 is NOT tagged with swift

        // Associate the "ios" tag with a subset
        await service.addTag("ios", toItemId: "email-1")
        await service.addTag("ios", toItemId: "note-1")

        // Filter by "swift" — 4 items, all types
        let swiftItems = await service.itemIds(forTagId: "swift")
        #expect(swiftItems.count == 4)
        #expect(swiftItems.contains("email-1"))
        #expect(swiftItems.contains("feed-article-1"))
        #expect(swiftItems.contains("note-1"))
        #expect(swiftItems.contains("link-1"))
        #expect(!swiftItems.contains("todo-1"))

        // Filter by "ios" — 2 items
        let iosItems = await service.itemIds(forTagId: "ios")
        #expect(iosItems.count == 2)
        #expect(iosItems.contains("email-1"))
        #expect(iosItems.contains("note-1"))
    }

    @Test func test_tagIds_forItemId() async {
        let service = await makeTagService()
        await service.add(tag: TagRecord(id: "swift", name: "swift"))
        await service.add(tag: TagRecord(id: "ios",   name: "ios"))

        await service.addTag("swift", toItemId: "email-1")
        await service.addTag("ios",   toItemId: "email-1")

        let tagIds = await service.tagIds(forItemId: "email-1")
        #expect(tagIds.count == 2)
        #expect(tagIds.contains("swift"))
        #expect(tagIds.contains("ios"))
    }

    @Test func test_removeTagAssociation() async {
        let service = await makeTagService()
        await service.add(tag: TagRecord(id: "t1", name: "Tag1"))
        await service.addTag("t1", toItemId: "item-1")
        await service.removeTag("t1", fromItemId: "item-1")

        let remaining = await service.itemIds(forTagId: "t1")
        #expect(remaining.isEmpty)
    }
}

// MARK: - SavedLinkRecord Tests

@Suite("SavedLinkRecord — persists after source deleted")
struct SavedLinkRecordTests {

    @Test func test_savedLink_persistsAfterSourceItemDeleted() {
        // Create a saved link associated with an email item
        let link = SavedLinkRecord(
            id: "link-1",
            urlString: "https://swift.org/blog/",
            title: "Swift Blog",
            sourceItemId: "email-42",
            tagIds: ["swift"]
        )
        #expect(link.sourceItemId == "email-42")
        #expect(!link.isOrphaned)

        // Source email is deleted — SavedLink clears its sourceItemId but persists
        let orphaned = link.orphaned()
        #expect(orphaned.sourceItemId == nil, "sourceItemId cleared after source deleted")
        #expect(orphaned.isOrphaned,           "isOrphaned is true after clearing")
        #expect(orphaned.urlString == "https://swift.org/blog/", "URL still intact")
        #expect(orphaned.title == "Swift Blog",                   "title still intact")
        #expect(orphaned.tagIds == ["swift"],                      "tags preserved")
        #expect(orphaned.id == link.id,                           "ID unchanged")
    }

    @Test func test_savedLink_noSourceItem() {
        // Link bookmarked outside any email context
        let link = SavedLinkRecord(urlString: "https://example.com")
        #expect(link.sourceItemId == nil)
        #expect(link.isOrphaned, "link with no source is immediately orphaned")
    }

    @Test func test_savedLink_tagsPreserved() {
        let link = SavedLinkRecord(
            urlString: "https://swiftpackageindex.com",
            tagIds: ["swift", "open-source", "packages"]
        )
        #expect(link.tagIds.count == 3)
        #expect(link.tagIds.contains("swift"))
    }
}
