import SwiftUI
import Textual
import Receptacle  // WikilinkParser, WikilinkParseResult

// MARK: - NoteEditorView

/// Split Markdown editor + rendered preview pane.
///
/// ## Platform layout
/// - **macOS**: `HSplitView` — left raw `TextEditor` (monospaced), right rendered preview.
/// - **iOS**: `TabView` with editor and preview tabs (HSplitView is macOS-only).
///
/// ## Textual integration
/// The preview pane renders Markdown via `StructuredText(markdown:)` from the Textual package.
/// `[[wikilinks]]` are pre-processed to Markdown links (`[Title](note://Title)`) before
/// passing to Textual, so they appear as tappable links in the preview.
///
/// ## Wikilink navigation
/// `[[NoteTitle]]` links are extracted by `WikilinkParser`.
/// Tapping a detected link calls `onNavigateToNote` with the target note's ID.
struct NoteEditorView: View {

    @Bindable var note: Note
    var onNavigateToNote: ((String) -> Void)?

    @State private var wikilinkRanges: [WikilinkMatch] = []

    private let parser = WikilinkParser()

    var body: some View {
#if os(macOS)
        macOSLayout
#else
        iOSLayout
#endif
    }

    // MARK: - macOS: HSplitView

#if os(macOS)
    private var macOSLayout: some View {
        HSplitView {
            editorPane
            previewPane
        }
    }
#endif

    // MARK: - iOS: TabView

#if os(iOS)
    private var iOSLayout: some View {
        TabView {
            editorPane
                .tabItem { Label("Edit", systemImage: "pencil") }
            previewPane
                .tabItem { Label("Preview", systemImage: "eye") }
        }
    }
#endif

    // MARK: - Shared panes

    private var editorPane: some View {
        TextEditor(text: $note.markdownContent)
            .font(.system(.body, design: .monospaced))
            .onChange(of: note.markdownContent) { _, newValue in
                note.updatedAt = Date()
                wikilinkRanges = parser.extractLinks(from: newValue)
            }
            .onAppear {
                wikilinkRanges = parser.extractLinks(from: note.markdownContent)
            }
    }

    private var previewPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // StructuredText renders Markdown including headers, bold, italic,
                // code blocks, lists, and tables. Wikilinks are pre-processed to
                // Markdown links so they render as clickable text.
                StructuredText(markdown: preprocessed(note.markdownContent))
                    .environment(\.openURL, OpenURLAction { url in
                        // Handle note:// scheme — navigate to the linked note.
                        if url.scheme == "note",
                           let target = url.host.map({ $0.removingPercentEncoding ?? $0 }) {
                            onNavigateToNote?(target)
                            return .handled
                        }
                        return .systemAction
                    })
                    .padding()

                if !wikilinkRanges.isEmpty {
                    Divider()
                    wikilinkLinksSection
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

    // MARK: - Wikilink pre-processing

    /// Convert `[[Title]]` to Markdown `[Title](note://Title)` for Textual rendering.
    ///
    /// The `note://` scheme is intercepted by the `openURL` environment action above,
    /// which calls `onNavigateToNote` to handle in-app navigation.
    private func preprocessed(_ markdown: String) -> String {
        var result = markdown
        for link in parser.extractLinks(from: markdown) {
            let raw = "[[\(link.target)]]"
            let encoded = link.target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? link.target
            let mdLink = "[\(link.target)](note://\(encoded))"
            result = result.replacingOccurrences(of: raw, with: mdLink)
        }
        return result
    }
}
