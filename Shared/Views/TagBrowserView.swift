import SwiftUI
import SwiftData

// MARK: - TagBrowserView

/// Cross-source tag filter.
///
/// Left: hierarchical tag tree (root tags + children).
/// Right: all items (emails, RSS, notes, saved links, todos) tagged with the selection.
///
/// Tags are cross-cutting — selecting a tag shows matching items from all sources.
struct TagBrowserView: View {
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var selectedTagId: String?

    /// Root tags (no parent).
    private var rootTags: [Tag] {
        allTags.filter { $0.parentTagId == nil }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTagId) {
                ForEach(rootTags) { tag in
                    TagRowView(tag: tag, allTags: allTags, selectedTagId: $selectedTagId)
                }
            }
            .navigationTitle("Tags")
            .listStyle(.sidebar)
        } detail: {
            if let tagId = selectedTagId {
                TaggedItemsView(tagId: tagId)
            } else {
                ContentUnavailableView(
                    "Select a Tag",
                    systemImage: "tag",
                    description: Text("Tags apply across emails, feeds, notes, saved links, and todos.")
                )
            }
        }
    }
}

// MARK: - TagRowView

/// A single tag row with optional disclosure group for children.
private struct TagRowView: View {
    let tag: Tag
    let allTags: [Tag]
    @Binding var selectedTagId: String?

    private var children: [Tag] {
        allTags.filter { $0.parentTagId == tag.id.uuidString }.sorted { $0.name < $1.name }
    }

    var body: some View {
        if children.isEmpty {
            Label(tag.name, systemImage: "tag")
                .tag(tag.id.uuidString)
        } else {
            DisclosureGroup {
                ForEach(children) { child in
                    TagRowView(tag: child, allTags: allTags, selectedTagId: $selectedTagId)
                }
            } label: {
                Label(tag.name, systemImage: "tag.fill")
                    .tag(tag.id.uuidString)
            }
        }
    }
}

// MARK: - TaggedItemsView

/// Detail view: cross-source items associated with the selected tag.
///
/// Phase 10: @Query predicates for each item type.
/// Items of all types that carry the selected tagId appear here.
///
/// ```swift
/// // Phase 10 — uncomment when item @Models have tagIds arrays:
/// @Query private var emails: [EmailItem]
/// @Query private var feedItems: [FeedItem]
/// @Query private var notes: [Note]
/// @Query private var savedLinks: [SavedLink]
///
/// // Filter in view body:
/// let taggedEmails    = emails.filter { $0.tagIds.contains(tagId) }
/// let taggedFeedItems = feedItems.filter { $0.tagIds.contains(tagId) }
/// let taggedNotes     = notes.filter { $0.tagIds.contains(tagId) }
/// let taggedLinks     = savedLinks.filter { $0.tagIds.contains(tagId) }
/// ```
struct TaggedItemsView: View {
    let tagId: String

    // Placeholder queries — uncomment as item types gain tagIds (Phase 10+):
    // @Query private var savedLinks: [SavedLink]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // SavedLink section
                VStack(alignment: .leading, spacing: 8) {
                    Label("Saved Links", systemImage: "link")
                        .font(.headline)
                    // Phase 10: render SavedLink rows filtered by tagId
                    Text("Saved links with this tag appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Email section
                VStack(alignment: .leading, spacing: 8) {
                    Label("Emails", systemImage: "envelope")
                        .font(.headline)
                    Text("Emails with this tag appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // RSS section
                VStack(alignment: .leading, spacing: 8) {
                    Label("Feed Articles", systemImage: "newspaper")
                        .font(.headline)
                    Text("RSS / Atom / JSON Feed articles with this tag appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Notes section
                VStack(alignment: .leading, spacing: 8) {
                    Label("Notes", systemImage: "note.text")
                        .font(.headline)
                    Text("Notes with this tag appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Tagged Items")
    }
}
