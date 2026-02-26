import SwiftUI

/// Split markdown editor + Textual-rendered preview pane for a Note.
///
/// Editor on left, live preview on right (or top/bottom on compact width).
/// Wikilinks `[[target]]` render as tappable navigation links.
/// Phase 11: integrate Textual (gonzalezreal/textual) for the preview pane.
struct NoteEditorView: View {
    @Bindable var note: Note
    @State private var isEditing = false

    var body: some View {
        HSplitView {
            // Edit pane
            TextEditor(text: $note.markdownContent)
                .font(.system(.body, design: .monospaced))
                .onChange(of: note.markdownContent) { _, _ in
                    note.updatedAt = Date()
                }

            // Preview pane — Phase 11: replace with Textual's MarkdownView
            ScrollView {
                // Placeholder until Textual is linked (Phase 11)
                Text(note.markdownContent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
    }
}
