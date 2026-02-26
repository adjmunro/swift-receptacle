// MARK: - NoteService

/// In-memory note store with wikilink resolution and AI-gated summarisation.
///
/// All notes are stored as `NoteRecord` value types. The SwiftData-backed
/// `Note` `@Model` in `Shared/` mirrors this design.
///
/// AI summarisation is permission-gated via `AIGate` with the `.summarise` feature.
/// The summarise operation APPENDS to note content — it never replaces existing text.
///
/// Usage:
/// ```swift
/// let service = NoteService(aiProvider: claudeProvider, gate: AIGate.shared, providerId: "claude")
/// var note = NoteRecord(title: "Meeting Notes")
/// service.add(note: note)
///
/// // Later — AI summarise from an email body:
/// let updated = try await service.summariseAndAppend(
///     itemContent: emailBody,
///     to: note.id
/// )
/// ```
public actor NoteService {

    private var notes: [String: NoteRecord] = [:]
    private let parser = WikilinkParser()

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

    // MARK: - CRUD

    /// Add or replace a note.
    public func add(note: NoteRecord) { notes[note.id] = note }

    /// Remove a note by ID.
    public func remove(noteId: String) { notes.removeValue(forKey: noteId) }

    /// Look up a note by ID.
    public func note(id: String) -> NoteRecord? { notes[id] }

    /// All notes sorted by title.
    public func allNotes() -> [NoteRecord] {
        notes.values.sorted { $0.title < $1.title }
    }

    // MARK: - AI Summarise → Append

    /// Summarise `itemContent` and **append** the result to the named note.
    ///
    /// Steps:
    /// 1. Looks up the note (returns `nil` if not found).
    /// 2. Pushes a revision to preserve the current content for rollback.
    /// 3. Runs `aiProvider.summarise` through `AIGate` with `.summarise` feature.
    /// 4. Appends the summary — existing content is preserved.
    /// 5. Stores the updated note and returns it.
    ///
    /// - Returns: The updated `NoteRecord`, or `nil` if `noteId` is unknown.
    /// - Throws: `AIProviderError.permissionDenied` if scope is `.never`.
    public func summariseAndAppend(
        itemContent: String,
        to noteId: String,
        entityId: String? = nil
    ) async throws -> NoteRecord? {
        guard var note = notes[noteId] else { return nil }

        note.pushRevision(changeDescription: "AI summarise")

        let provider = aiProvider
        let summary = try await gate.perform(
            providerId: providerId,
            feature: .summarise,
            entityId: entityId
        ) {
            try await provider.summarise(text: itemContent)
        }

        note.appendSummary(summary)
        notes[noteId] = note
        return note
    }

    // MARK: - Wikilink Resolution

    /// Resolve `[[wikilinks]]` in the named note against all stored notes.
    ///
    /// Updates and stores the note's `linkedNoteIds`.
    /// - Returns: The IDs of notes that were successfully resolved.
    @discardableResult
    public func resolveWikilinks(in noteId: String) -> [String] {
        guard var note = notes[noteId] else { return [] }
        let allTitles = notes.values.map { (id: $0.id, title: $0.title) }
        note.updateLinkedNoteIds(using: parser, allNotes: allTitles)
        notes[noteId] = note
        return note.linkedNoteIds
    }
}
