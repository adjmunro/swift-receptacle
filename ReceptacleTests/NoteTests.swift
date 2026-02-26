// NoteTests.swift
// CLI-compatible: only `import Testing` (no Foundation).
// Run via: swift test  (or open in Xcode for full output)

import Testing
import Receptacle

// MARK: - NoteRevisionRecord Tests

@Suite("NoteRevisionRecord")
struct NoteRevisionRecordTests {

    @Test func basicProperties() {
        let rev = NoteRevisionRecord(content: "# My Note\n\nSome content.")
        #expect(rev.content == "# My Note\n\nSome content.")
        #expect(rev.changeDescription == nil)
    }

    @Test func withDescription() {
        let rev = NoteRevisionRecord(content: "Body", changeDescription: "AI summarise")
        #expect(rev.changeDescription == "AI summarise")
    }
}

// MARK: - NoteRecord: Revision Tests

@Suite("NoteRecord — revision history")
struct NoteRecordRevisionTests {

    @Test func test_noteRevision_pushAndRestore() {
        var note = NoteRecord(title: "Test Note", markdownContent: "Original content.")
        #expect(note.revisionHistory.isEmpty)

        // Push revision before edit
        note.pushRevision(changeDescription: "Before AI edit")
        #expect(note.revisionHistory.count == 1)
        #expect(note.revisionHistory[0].content == "Original content.")
        #expect(note.revisionHistory[0].changeDescription == "Before AI edit")

        // Modify content
        note.markdownContent = "Modified by AI."
        #expect(note.markdownContent == "Modified by AI.")

        // Restore from revision
        let success = note.restoreRevision(at: 0)
        #expect(success)
        #expect(note.markdownContent == "Original content.", "content restored from revision")
    }

    @Test func multipleRevisions() {
        var note = NoteRecord(title: "Note", markdownContent: "v1")
        note.pushRevision(changeDescription: "edit 1")
        note.markdownContent = "v2"
        note.pushRevision(changeDescription: "edit 2")
        note.markdownContent = "v3"

        #expect(note.revisionHistory.count == 2)
        #expect(note.revisionHistory[0].content == "v1")
        #expect(note.revisionHistory[1].content == "v2")

        // Restore to v1
        note.restoreRevision(at: 0)
        #expect(note.markdownContent == "v1")

        // Revision history is preserved after restore
        #expect(note.revisionHistory.count == 2, "restoring does not truncate history")
    }

    @Test func restoreOutOfBounds() {
        var note = NoteRecord(title: "Note", markdownContent: "content")
        let result = note.restoreRevision(at: 5)
        #expect(!result, "out-of-bounds restore returns false")
        #expect(note.markdownContent == "content", "content unchanged")
    }
}

// MARK: - NoteRecord: Append-not-Replace Tests

@Suite("NoteRecord — AI summarise append")
struct NoteRecordSummariseTests {

    @Test func test_aiSummarise_appendsToNote_notReplaces() {
        var note = NoteRecord(
            title: "Meeting Notes",
            markdownContent: "## Discussion\n\nWe talked about the roadmap."
        )
        let originalContent = note.markdownContent

        // Push revision first (as NoteService does)
        note.pushRevision(changeDescription: "AI summarise")

        // Append summary
        note.appendSummary("Key points: roadmap discussed.")

        // Existing content is preserved
        #expect(note.markdownContent.contains(originalContent),
                "original content still present after appendSummary")
        // Summary is appended
        #expect(note.markdownContent.contains("Key points: roadmap discussed."),
                "summary appended to note")
        // Content grew — not replaced
        #expect(note.markdownContent.count > originalContent.count,
                "content is longer after append (not replaced)")
    }

    @Test func appendToEmptyNote() {
        var note = NoteRecord(title: "Empty")
        note.appendSummary("First summary.")
        #expect(note.markdownContent.contains("First summary."))
        // No leading separator when starting empty
        #expect(!note.markdownContent.hasPrefix("\n"), "empty note: no leading newline")
    }

    @Test func multipleAppends() {
        var note = NoteRecord(title: "Note", markdownContent: "Original.")
        note.appendSummary("Summary 1.")
        note.appendSummary("Summary 2.")
        #expect(note.markdownContent.contains("Original."))
        #expect(note.markdownContent.contains("Summary 1."))
        #expect(note.markdownContent.contains("Summary 2."))
    }

    @Test func undoRestoresPreSummariseContent() {
        var note = NoteRecord(title: "Note", markdownContent: "My original text.")
        note.pushRevision(changeDescription: "AI summarise")
        note.appendSummary("Generated summary.")

        // Undo by restoring the revision
        note.restoreRevision(at: 0)
        #expect(note.markdownContent == "My original text.",
                "restoring revision undoes the AI summary append")
    }
}

// MARK: - NoteRecord: Wikilink Resolution Tests

@Suite("NoteRecord — wikilink resolution")
struct NoteRecordWikilinkTests {

    @Test func test_wikilinks_resolveToNoteIds() {
        var note = NoteRecord(
            id: "note-a",
            title: "Project Overview",
            markdownContent: "See [[Meeting Notes]] and [[Research]] for context."
        )

        let allNotes: [(id: String, title: String)] = [
            (id: "note-b", title: "Meeting Notes"),
            (id: "note-c", title: "Research"),
            (id: "note-d", title: "Unrelated"),
        ]
        let parser = WikilinkParser()
        note.updateLinkedNoteIds(using: parser, allNotes: allNotes)

        #expect(note.linkedNoteIds.count == 2, "two wikilinks resolved")
        #expect(note.linkedNoteIds.contains("note-b"), "Meeting Notes → note-b")
        #expect(note.linkedNoteIds.contains("note-c"), "Research → note-c")
        #expect(!note.linkedNoteIds.contains("note-d"), "Unrelated not linked")
    }

    @Test func test_markdownRender_wikilinksAsNavigableLinks() {
        // Verify that wikilinks extracted from content can serve as navigation targets.
        // "Navigable" = resolved to a note ID via the note store.
        let parser = WikilinkParser()
        let content = "Refer to [[Architecture]] and [[API Design]] for details."
        let links = parser.extractLinks(from: content)

        let knownNotes: [(id: String, title: String)] = [
            (id: "arch-note", title: "Architecture"),
            (id: "api-note",  title: "API Design"),
        ]

        // Resolve each link target to a note ID
        let resolved = links.compactMap { link -> (target: String, id: String)? in
            guard let id = knownNotes.first(where: {
                $0.title.caseInsensitiveCompare(link.target) == .orderedSame
            })?.id else { return nil }
            return (target: link.target, id: id)
        }

        #expect(resolved.count == 2, "all wikilinks resolve to note IDs")
        #expect(resolved.first(where: { $0.target == "Architecture" })?.id == "arch-note")
        #expect(resolved.first(where: { $0.target == "API Design" })?.id == "api-note")
    }

    @Test func unresolvedWikilinks() {
        var note = NoteRecord(
            title: "Note",
            markdownContent: "See [[Unknown Note]] for reference."
        )
        let parser = WikilinkParser()
        note.updateLinkedNoteIds(using: parser, allNotes: [])
        #expect(note.linkedNoteIds.isEmpty, "unresolved wikilinks produce no linkedNoteIds")
    }
}

// MARK: - NoteService Tests

@Suite("NoteService")
struct NoteServiceTests {

    private func makeService(scope: AIScope = .always) async -> NoteService {
        let mockAI = MockAIProvider()
        let manager = AIPermissionManager()
        await manager.set(scope: scope, providerId: "mock-ai", feature: .summarise)
        let gate = AIGate(permissionManager: manager)
        return NoteService(aiProvider: mockAI, gate: gate, providerId: "mock-ai")
    }

    @Test func crudOperations() async {
        let service = await makeService()
        let note = NoteRecord(id: "n1", title: "Note 1", markdownContent: "Hello.")
        await service.add(note: note)

        let retrieved = await service.note(id: "n1")
        #expect(retrieved?.title == "Note 1")
        #expect(retrieved?.markdownContent == "Hello.")

        await service.remove(noteId: "n1")
        let gone = await service.note(id: "n1")
        #expect(gone == nil)
    }

    @Test func summariseAndAppend_appendsContent() async throws {
        let mockAI = MockAIProvider()
        await mockAI.set(summariseResult: "Three key points discussed.")
        let manager = AIPermissionManager()
        await manager.set(scope: .always, providerId: "mock-ai", feature: .summarise)
        let gate = AIGate(permissionManager: manager)
        let service = NoteService(aiProvider: mockAI, gate: gate, providerId: "mock-ai")

        let note = NoteRecord(id: "n1", title: "Meeting", markdownContent: "Original notes.")
        await service.add(note: note)

        let updated = try await service.summariseAndAppend(
            itemContent: "Long email about the meeting topics.",
            to: "n1"
        )

        #expect(updated != nil)
        #expect(updated?.markdownContent.contains("Original notes.") == true,
                "original content preserved")
        #expect(updated?.markdownContent.contains("Three key points discussed.") == true,
                "summary appended")
        #expect(updated?.revisionHistory.count == 1,
                "one revision pushed before summarise")
        #expect(updated?.revisionHistory[0].content == "Original notes.",
                "revision captures pre-summarise content")
    }

    @Test func summariseAndAppend_blockedByPermission() async throws {
        let service = await makeService(scope: .never)
        let note = NoteRecord(id: "n2", title: "Blocked Note", markdownContent: "Content.")
        await service.add(note: note)

        var threw = false
        do {
            _ = try await service.summariseAndAppend(itemContent: "email text", to: "n2")
        } catch AIProviderError.permissionDenied {
            threw = true
        }
        #expect(threw, "summariseAndAppend blocked when permission is .never")
    }

    @Test func summariseAndAppend_unknownNote() async throws {
        let service = await makeService()
        let result = try await service.summariseAndAppend(
            itemContent: "email",
            to: "does-not-exist"
        )
        #expect(result == nil, "returns nil for unknown note ID")
    }

    @Test func resolveWikilinks() async {
        let service = await makeService()
        let noteA = NoteRecord(id: "a", title: "Note A",
                               markdownContent: "Links to [[Note B]] and [[Note C]].")
        let noteB = NoteRecord(id: "b", title: "Note B", markdownContent: "B content.")
        let noteC = NoteRecord(id: "c", title: "Note C", markdownContent: "C content.")
        await service.add(note: noteA)
        await service.add(note: noteB)
        await service.add(note: noteC)

        let resolved = await service.resolveWikilinks(in: "a")
        #expect(resolved.count == 2)
        #expect(resolved.contains("b"))
        #expect(resolved.contains("c"))

        // The stored note is updated too
        let updated = await service.note(id: "a")
        #expect(updated?.linkedNoteIds.contains("b") == true)
        #expect(updated?.linkedNoteIds.contains("c") == true)
    }
}
