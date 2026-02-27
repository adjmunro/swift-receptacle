import SwiftUI
import SwiftData
import Receptacle  // NoteService, AIProvider, AIGate, NoteRecord

// MARK: - SidebarNoteView

/// Resizable, collapsible right-side notes panel.
///
/// Linked to the currently viewed item — shows any `Note` associated with it.
///
/// ## AI Summarise behaviour
/// Runs `noteService.summariseAndAppend(itemContent:to:)`, then **appends** the result
/// to the note (never replaces existing content). A revision is pushed automatically
/// inside `NoteService` so the pre-summarise state can be restored.
///
/// ## Wikilink navigation
/// Tapping a `[[wikilink]]` in `NoteEditorView` calls `onNavigateToNote`
/// with the target note's ID — the parent view handles the navigation.
struct SidebarNoteView: View {
    let linkedItemId: String
    let itemContent: String
    let noteService: NoteService

    /// Called when the user taps a [[wikilink]] — navigate to that note.
    var onNavigateToNote: ((String) -> Void)?
    /// Called when the user wants to create a new note linked to this item.
    var onCreateNote: (() -> Void)?

    @Query private var allNotes: [Note]
    @State private var isExpanded = true
    @State private var isSummarising = false
    @State private var errorMessage: String? = nil

    private var linkedNote: Note? {
        allNotes.first { $0.linkedItemIds.contains(linkedItemId) }
    }

    var body: some View {
        if isExpanded {
            VStack(spacing: 0) {
                headerBar
                Divider()

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    Divider()
                }

                if let note = linkedNote {
                    NoteEditorView(note: note, onNavigateToNote: onNavigateToNote)
                } else {
                    VStack(spacing: 8) {
                        Text("No note linked to this item.")
                            .foregroundStyle(.secondary)
                        Button("Create Note") { onCreateNote?() }
                            .buttonStyle(.borderless)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        } else {
            Button { withAnimation { isExpanded = true } } label: {
                Image(systemName: "sidebar.right").padding()
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
            Spacer()
            if isSummarising { ProgressView().controlSize(.small) }
            Button {
                Task { await summariseAndAppend() }
            } label: {
                Label("Summarise", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderless)
            .disabled(isSummarising || itemContent.isEmpty || linkedNote == nil)
            .help("Summarise the current item and append to the linked note")

            Button { withAnimation { isExpanded = false } } label: {
                Image(systemName: "sidebar.right")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - AI Summarise → Append

    private func summariseAndAppend() async {
        guard let note = linkedNote else { return }
        isSummarising = true
        errorMessage = nil
        defer { isSummarising = false }

        do {
            // NoteService.summariseAndAppend pushes a revision, runs AIGate-gated
            // summarise, and returns the updated NoteRecord. We then sync the
            // SwiftData Note @Model to match.
            let updatedRecord = try await noteService.summariseAndAppend(
                itemContent: itemContent,
                to: note.id.uuidString
            )
            if let updated = updatedRecord {
                note.markdownContent = updated.markdownContent
                note.updatedAt = updated.updatedAt
                note.revisionHistory = updated.revisionHistory.map {
                    NoteRevision(
                        timestamp: $0.timestamp,
                        content: $0.content,
                        changeDescription: $0.changeDescription
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
