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
/// All item types are queried and filtered client-side by `tagId`.
/// SwiftData does not support `array contains` predicates, so filtering
/// happens in Swift after loading all items.
struct TaggedItemsView: View {
    let tagId: String

    @Query(sort: \EmailItem.date, order: .reverse) private var allEmails: [EmailItem]
    @Query(sort: \FeedItem.date, order: .reverse) private var allFeedItems: [FeedItem]
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
    @Query(sort: \SavedLink.savedAt, order: .reverse) private var allSavedLinks: [SavedLink]

    private var taggedEmails: [EmailItem]    { allEmails.filter    { $0.tagIds.contains(tagId) && !$0.isDeleted && !$0.isArchived } }
    private var taggedFeedItems: [FeedItem]  { allFeedItems.filter  { $0.tagIds.contains(tagId) } }
    private var taggedNotes: [Note]          { allNotes.filter      { $0.tagIds.contains(tagId) } }
    private var taggedLinks: [SavedLink]     { allSavedLinks.filter { $0.tagIds.contains(tagId) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Saved Links
                if !taggedLinks.isEmpty {
                    tagSection(title: "Saved Links", systemImage: "link") {
                        ForEach(taggedLinks) { link in
                            savedLinkRow(link)
                        }
                    }
                }

                // Emails
                if !taggedEmails.isEmpty {
                    tagSection(title: "Emails", systemImage: "envelope") {
                        ForEach(taggedEmails) { email in
                            emailRow(email)
                        }
                    }
                }

                // Feed Articles
                if !taggedFeedItems.isEmpty {
                    tagSection(title: "Feed Articles", systemImage: "newspaper") {
                        ForEach(taggedFeedItems) { feed in
                            feedRow(feed)
                        }
                    }
                }

                // Notes
                if !taggedNotes.isEmpty {
                    tagSection(title: "Notes", systemImage: "note.text") {
                        ForEach(taggedNotes) { note in
                            noteRow(note)
                        }
                    }
                }

                if taggedLinks.isEmpty && taggedEmails.isEmpty && taggedFeedItems.isEmpty && taggedNotes.isEmpty {
                    ContentUnavailableView(
                        "No Tagged Items",
                        systemImage: "tag.slash",
                        description: Text("No items carry this tag yet.")
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Tagged Items")
    }

    // MARK: - Section builder

    @ViewBuilder
    private func tagSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
    }

    // MARK: - Row views

    private func savedLinkRow(_ link: SavedLink) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(link.title ?? link.urlString)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(link.savedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "link")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func emailRow(_ email: EmailItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(email.subject)
                .font(.subheadline)
                .lineLimit(1)
            HStack {
                Text(email.fromAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(email.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func feedRow(_ feed: FeedItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(feed.title)
                .font(.subheadline)
                .lineLimit(1)
            Text(feed.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func noteRow(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.title)
                .font(.subheadline)
            Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
