import SwiftUI
import SwiftData

/// Resizable, collapsible right-side notes panel.
///
/// Linked to the currently viewed item — shows any `Note` associated with it.
/// AI Summarise: runs summarisation on the post card's content and APPENDS
/// the result to the note (never replaces existing content).
struct SidebarNoteView: View {
    let linkedItemId: String
    let itemContent: String

    @Query private var allNotes: [Note]
    @State private var isExpanded = true
    @State private var isSummarising = false

    var linkedNote: Note? {
        allNotes.first { $0.linkedItemIds.contains(linkedItemId) }
    }

    var body: some View {
        if isExpanded {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Label("Notes", systemImage: "note.text")
                        .font(.headline)
                    Spacer()
                    Button {
                        Task { await summariseAndAppend() }
                    } label: {
                        Label("Summarise", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderless)
                    .disabled(isSummarising || itemContent.isEmpty)
                    Button {
                        withAnimation { isExpanded = false }
                    } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                if let note = linkedNote {
                    NoteEditorView(note: note)
                } else {
                    VStack(spacing: 8) {
                        Text("No note linked to this item.")
                            .foregroundStyle(.secondary)
                        Button("Create Note") {
                            // TODO Phase 11: create Note + link to linkedItemId
                        }
                        .buttonStyle(.borderless)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        } else {
            Button {
                withAnimation { isExpanded = true }
            } label: {
                Image(systemName: "sidebar.right")
                    .padding()
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - AI Summarise

    private func summariseAndAppend() async {
        guard let note = linkedNote else { return }
        isSummarising = true
        defer { isSummarising = false }
        // TODO Phase 11:
        // let summary = try await aiProvider.summarise(text: itemContent)
        // note.pushRevision(changeDescription: "AI summarise")
        // note.markdownContent += "\n\n---\n**Summary**\n\(summary)"
    }
}
