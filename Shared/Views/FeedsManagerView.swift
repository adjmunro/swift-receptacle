import SwiftUI
import SwiftData
import Receptacle

// MARK: - FeedsManagerView

/// Browse and manage RSS/Atom/JSON Feed subscriptions.
///
/// Only shows contacts with `type == .feed`. The "+" button opens
/// `AddFeedSheet`; tapping a row opens `ContactDetailView` which
/// presents as "Edit Feed" for feed-type contacts.
struct FeedsManagerView: View {
    @Query(sort: \Contact.displayName) private var allContacts: [Contact]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedFeed: Contact?
    @State private var showingAddFeed = false

    var feeds: [Contact] {
        let feedsOnly = allContacts.filter { $0.type == .feed }
        guard !searchText.isEmpty else { return feedsOnly }
        return feedsOnly.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(feeds, selection: $selectedFeed) { feed in
            FeedRowView(contact: feed)
                .tag(feed)
        }
        .searchable(text: $searchText)
        .navigationTitle("Feeds")
        .overlay {
            if feeds.isEmpty && searchText.isEmpty {
                ContentUnavailableView(
                    "No feeds yet",
                    systemImage: "dot.radiowaves.up.forward",
                    description: Text("Tap + to subscribe to an RSS, Atom, or JSON feed.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddFeed = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Subscribe to an RSS, Atom, or JSON feed")
            }
        }
        .sheet(item: $selectedFeed) { feed in
            ContactDetailView(contact: feed)
        }
        .sheet(isPresented: $showingAddFeed) {
            AddFeedSheet()
        }
    }
}

// MARK: - FeedRowView

private struct FeedRowView: View {
    let contact: Contact

    /// Best short label for the feed source — prefer the URL host,
    /// fall back to the raw URL string if parsing fails.
    private var sourceLabel: String {
        guard let urlStr = contact.sourceIdentifiers
            .first(where: { $0.type == .rss })?.value else { return "" }
        return URL(string: urlStr)?.host ?? urlStr
    }

    var body: some View {
        HStack {
            Image(systemName: "dot.radiowaves.up.forward")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                if !sourceLabel.isEmpty {
                    Text(sourceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Feeds Manager") {
    NavigationStack {
        FeedsManagerView()
    }
    .modelContainer(PreviewData.container)
#if os(macOS)
    .frame(minWidth: 500, idealWidth: 560, minHeight: 400)
#endif
}
