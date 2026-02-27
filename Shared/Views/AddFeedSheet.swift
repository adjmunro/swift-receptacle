import SwiftUI
import SwiftData
@preconcurrency import FeedKit
import Receptacle

// MARK: - AddFeedSheet

/// Sheet for subscribing to an RSS/Atom/JSON Feed.
///
/// Flow:
/// 1. User enters a URL (must start with `http`).
/// 2. On "Add", the sheet fetches the feed to extract its title.
/// 3. Creates a `Contact` (type: `.feed`) + `Entity` in SwiftData.
/// 4. Calls `FeedSyncService.syncFeed` to immediately import articles.
/// 5. Dismisses.
struct AddFeedSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var urlString = ""
    @State private var nameOverride = ""
    @State private var selectedTagIds: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isAddDisabled: Bool {
        urlString.trimmingCharacters(in: .whitespaces).isEmpty || isLoading
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // "Feed URL" is the left-column label on macOS Form.
                    // The `prompt:` argument renders as placeholder text inside the field.
                    TextField(
                        "Feed URL",
                        text: $urlString,
                        prompt: Text("https://example.com/feed.xml")
                    )
                    .autocorrectionDisabled()
#if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
#endif

                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Feed URL")
                }

                Section {
                    TextField(
                        "Name",
                        text: $nameOverride,
                        prompt: Text("Auto-filled from feed title")
                    )
                } header: {
                    Text("Name (optional)")
                } footer: {
                    Text("Left blank, the feed's own title element is used.")
                }

                TagPickerSection(tagIds: $selectedTagIds, allTags: allTags)
            }
            .formStyle(.grouped)
            .navigationTitle("Add Feed")
#if os(macOS)
            .navigationSubtitle("RSS · Atom · JSON Feed")
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Add") {
                            Task { await addFeed() }
                        }
                        .disabled(isAddDisabled)
                    }
                }
            }
        }
        // Prevents accidental close while the network fetch is in flight.
        .interactiveDismissDisabled(isLoading)
#if os(macOS)
        .frame(minWidth: 400, idealWidth: 440, minHeight: 280)
#endif
    }

    // MARK: Add

    private func addFeed() async {
        let urlStr = urlString.trimmingCharacters(in: .whitespaces)
        guard urlStr.lowercased().hasPrefix("http") else {
            errorMessage = "URL must start with http:// or https://"
            return
        }
        guard let url = URL(string: urlStr) else {
            errorMessage = "Invalid URL."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Fetch feed to extract its title.
        var fetchedTitle: String?
        if let (data, _) = try? await URLSession.shared.data(from: url) {
            if case .success(let feed) = FeedParser(data: data).parse() {
                switch feed {
                case .rss(let rss):   fetchedTitle = rss.title
                case .atom(let atom): fetchedTitle = atom.title
                case .json(let json): fetchedTitle = json.title
                }
            }
        }

        let trimmedOverride = nameOverride.trimmingCharacters(in: .whitespaces)
        let displayName = trimmedOverride.isEmpty
            ? (fetchedTitle ?? urlStr)
            : trimmedOverride

        // Persist Contact + Entity.
        let contact = Contact(
            displayName: displayName,
            type: .feed,
            sourceIdentifiers: [SourceIdentifier(type: .rss, value: urlStr)]
        )
        let entity = Entity(
            displayName: displayName,
            contactIds: [contact.id.uuidString],
            retentionPolicy: .keepLatest(50)
        )
        entity.tagIds = selectedTagIds
        modelContext.insert(contact)
        modelContext.insert(entity)
        try? modelContext.save()

        // Immediately populate with existing articles.
        let config = FeedConfig(
            feedId: contact.id.uuidString,
            displayName: displayName,
            feedURLString: urlStr,
            entityId: entity.id.uuidString
        )
        await FeedSyncService.syncFeed(config: config, context: modelContext)

        dismiss()
    }
}

// MARK: - Preview

#Preview("Add Feed Sheet") {
    AddFeedSheet()
        .modelContainer(PreviewData.container)
}
