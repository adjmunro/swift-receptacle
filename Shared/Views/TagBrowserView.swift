import SwiftUI
import SwiftData

/// Cross-source tag filter: shows all items (emails, RSS, notes, links, todos)
/// tagged with the selected tag.
struct TagBrowserView: View {
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var selectedTagId: String?

    var body: some View {
        NavigationSplitView {
            List(tags, selection: $selectedTagId) { tag in
                Label(tag.name, systemImage: "tag")
                    .tag(tag.id.uuidString)
            }
            .navigationTitle("Tags")
        } detail: {
            if let tagId = selectedTagId {
                TaggedItemsView(tagId: tagId)
            } else {
                ContentUnavailableView("Select a Tag", systemImage: "tag")
            }
        }
    }
}

struct TaggedItemsView: View {
    let tagId: String

    // Phase 10: query all item types that contain tagId
    // @Query(filter: #Predicate<EmailItem> { $0.tagIds.contains(tagId) })
    // private var emails: [EmailItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Emails, feed articles, notes, and saved links tagged here.")
                    .foregroundStyle(.secondary)
                    .padding()
                // TODO Phase 10: render EmailItem, FeedItem, Note, SavedLink rows
            }
        }
        .navigationTitle("Tagged Items")
    }
}
