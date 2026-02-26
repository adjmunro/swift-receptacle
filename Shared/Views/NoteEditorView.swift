import SwiftUI
import Receptacle  // WikilinkParser, WikilinkParseResult

// MARK: - NoteEditorView

/// Split Markdown editor + rendered preview pane.
///
/// Left: raw `TextEditor` (monospaced). Right: rendered preview.
///
/// ## Textual integration (Phase 11, requires Xcode + package linked):
/// ```swift
/// import Textual
///
/// // Replace the ScrollView preview with:
/// MarkdownText(note.markdownContent)
///     .padding()
///
/// // MarkdownText renders headers, bold, italic, code blocks, lists.
/// // For [[wikilink]] rendering, pre-process the content to convert
/// // wikilinks to Markdown links before passing to MarkdownText.
/// ```
///
/// ## Wikilink navigation
/// `[[NoteTitle]]` links are extracted by `WikilinkParser`.
/// Tapping a detected link calls `onNavigateToNote` with the target note's ID.
struct NoteEditorView: View {

    @Bindable var note: Note
    var onNavigateToNote: ((String) -> Void)?

    @State private var wikilinkRanges: [WikiLink] = []

    private let parser = WikilinkParser()

    var body: some View {
        HSplitView {
            // ── Left: raw Markdown editor ──
            TextEditor(text: $note.markdownContent)
                .font(.system(.body, design: .monospaced))
                .onChange(of: note.markdownContent) { _, newValue in
                    note.updatedAt = Date()
                    wikilinkRanges = parser.extractLinks(from: newValue)
                }
                .onAppear {
                    wikilinkRanges = parser.extractLinks(from: note.markdownContent)
                }

            // ── Right: rendered preview ──
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

                    // Phase 11 (Textual linked in Xcode):
                    // MarkdownText(preprocessed(note.markdownContent))
                    //     .padding()

                    // Placeholder: plain text + wikilink chip list
                    Text(note.markdownContent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()

                    if !wikilinkRanges.isEmpty {
                        Divider()
                        wikilinkLinksSection
                    }
                }
            }
        }
    }

    // MARK: - Wikilink chips

    private var wikilinkLinksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Linked notes")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(wikilinkRanges, id: \.target) { link in
                        Button {
                            // In a full implementation, resolve link.target to a note ID
                            // via NoteService.resolveWikilinks(), then call onNavigateToNote.
                            //
                            // Placeholder: pass target title as the "ID" for now.
                            onNavigateToNote?(link.target)
                        } label: {
                            Label(link.target, systemImage: "arrow.right.circle")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Wikilink pre-processing (Phase 11 helper)

    /// Convert `[[Title]]` to Markdown `[Title](note://Title)` for Textual rendering.
    ///
    /// ```swift
    /// // Uncomment when Textual is linked:
    /// private func preprocessed(_ markdown: String) -> String {
    ///     var result = markdown
    ///     for link in parser.extractLinks(from: markdown) {
    ///         let raw = "[[\(link.target)]]"
    ///         let mdLink = "[\(link.target)](note://\(link.target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? link.target))"
    ///         result = result.replacingOccurrences(of: raw, with: mdLink)
    ///     }
    ///     return result
    /// }
    /// ```
}
