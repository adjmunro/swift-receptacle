import SwiftUI
import SwiftData
import Receptacle

// MARK: - PostCardItem

/// A unified, source-agnostic representation of one item for display in PostFeedView.
///
/// Adapts both `EmailItem` and `FeedItem` (and future item types) into a single
/// value type so PostFeedView can build one sorted, filterable list.
struct PostCardItem: Identifiable, Sendable {
    let id: String
    let date: Date
    let summary: String
    let title: String?
    let importanceLevel: ImportanceLevel
    let sourceType: SourceType
    let isRead: Bool
    let entityId: String
    // Phase 9: reply-to address for email items
    let replyToAddress: String?
    // Phase 7: link URL for feed items
    let linkURLString: String?
}

extension EmailItem {
    var asPostCardItem: PostCardItem {
        PostCardItem(
            id: id,
            date: date,
            summary: summary,
            title: subject,
            importanceLevel: .normal,   // Phase 1 elevation applied at query time (future)
            sourceType: .email,
            isRead: isRead,
            entityId: entityId,
            replyToAddress: effectiveReplyToAddress,
            linkURLString: nil
        )
    }
}

extension FeedItem {
    var asPostCardItem: PostCardItem {
        PostCardItem(
            id: id,
            date: date,
            summary: summary,
            title: title,
            importanceLevel: .normal,
            sourceType: .rss,
            isRead: isRead,
            entityId: entityId,
            replyToAddress: nil,
            linkURLString: linkURLString
        )
    }
}

// MARK: - PostFeedView

/// Per-entity feed: source tabs at the top, scrollable post-card list below.
///
/// Source tabs are computed from whatever items currently exist for this entity
/// — if only email exists, only the email tab appears (plus "All"). This means
/// Phase 6 (live data wiring) requires no API changes here.
///
/// Tab ordering on first open:
///   - Tabs with unread items → sorted by unread count descending
///   - All-read → sorted by SourceUsage.viewCount (Phase 6)
struct PostFeedView: View {
    let entity: Entity

    @Query private var emailItems: [EmailItem]
    @Query private var feedItems: [FeedItem]
    @State private var selectedSource: SourceType? = nil

    // MARK: Init

    init(entity: Entity) {
        self.entity = entity
        let eid = entity.id.uuidString
        _emailItems = Query(filter: #Predicate<EmailItem> {
            $0.entityId == eid && !$0.isArchived && !$0.isDeleted
        }, sort: \.date, order: .reverse)
        _feedItems = Query(filter: #Predicate<FeedItem> {
            $0.entityId == eid
        }, sort: \.date, order: .reverse)
    }

    // MARK: Derived data

    /// All items merged and sorted newest-first.
    var allItems: [PostCardItem] {
        let emails = emailItems.map(\.asPostCardItem)
        let feeds  = feedItems.map(\.asPostCardItem)
        return (emails + feeds).sorted { $0.date > $1.date }
    }

    /// Items visible in the currently selected tab.
    var visibleItems: [PostCardItem] {
        guard let source = selectedSource else { return allItems }
        return allItems.filter { $0.sourceType == source }
    }

    /// Source types that actually have items, for rendering the tab bar.
    ///
    /// iMessage is macOS-only (read via `~/Library/Messages/chat.db` with Full Disk Access).
    /// It is excluded from the tab bar on iOS where that API is unavailable.
    var availableSources: [SourceType] {
        var seen = Set<SourceType>()
        for item in allItems { seen.insert(item.sourceType) }
        // Stable order: email before rss before others
        return SourceType.allCases.filter { type in
#if os(iOS)
            // iMessage source is macOS-only — hide its tab on iOS
            guard type != .iMessage else { return false }
#endif
            return seen.contains(type)
        }
    }

    /// Unread count per source type.
    func unreadCount(for source: SourceType?) -> Int {
        let pool = source.map { s in allItems.filter { $0.sourceType == s } } ?? allItems
        return pool.filter { !$0.isRead }.count
    }

    // MARK: Body

    /// iOS only: shows the linked-note panel as a full-screen sheet.
    @State private var showNotesSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Source tab bar
            if availableSources.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        SourceTabButton(
                            label: "All",
                            unreadCount: unreadCount(for: nil),
                            isSelected: selectedSource == nil
                        ) { selectedSource = nil }

                        ForEach(availableSources, id: \.self) { source in
                            SourceTabButton(
                                label: source.displayName,
                                unreadCount: unreadCount(for: source),
                                isSelected: selectedSource == source
                            ) { selectedSource = source }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 44)

                Divider()
            }

            // Post card feed
            if visibleItems.isEmpty {
                ContentUnavailableView(
                    "No items",
                    systemImage: "tray",
                    description: Text("New items will appear here when synced.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(visibleItems) { item in
                            PostCardView(item: item, entity: entity)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(entity.displayName)
#if os(macOS)
        .navigationSubtitle(entity.retentionPolicy.displayName)
#else
        // iOS: Notes panel as a toolbar sheet button.
        // macOS: SidebarNoteView is hosted in an HSplitView by the parent ContentView.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNotesSheet = true
                } label: {
                    Label("Notes", systemImage: "note.text")
                }
            }
        }
        .sheet(isPresented: $showNotesSheet) {
            // Phase 13: pass NoteService + itemContent when wired in Xcode.
            // SidebarNoteView is presented as a full-screen sheet on iOS.
            NavigationStack {
                Text("Notes panel — wire NoteService in Xcode target.")
                    .foregroundStyle(.secondary)
                    .navigationTitle("Notes")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showNotesSheet = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
#endif
    }
}

// MARK: - SourceTabButton

struct SourceTabButton: View {
    let label: String
    let unreadCount: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SourceType display name

extension SourceType {
    var displayName: String {
        switch self {
        case .email:    return "Email"
        case .rss:      return "RSS"
        case .slack:    return "Slack"
        case .teams:    return "Teams"
        case .iMessage: return "iMessage"
        case .matrix:   return "Matrix"
        case .xmpp:     return "XMPP"
        case .discord:  return "Discord"
        case .webView:  return "Web"
        case .calendar: return "Calendar"
        }
    }
}

// MARK: - Preview

#Preview("Post Feed — email + rss") {
    let entity = (try? PreviewData.container.mainContext
        .fetch(FetchDescriptor<Entity>(
            predicate: #Predicate { $0.displayName == "Swift.org Blog" }
        )))?.first ?? Entity(displayName: "Preview Entity")

    return NavigationStack {
        PostFeedView(entity: entity)
    }
    .modelContainer(PreviewData.container)
}

#Preview("Post Feed — email only") {
    let entity = (try? PreviewData.container.mainContext
        .fetch(FetchDescriptor<Entity>(
            predicate: #Predicate { $0.displayName == "Mum" }
        )))?.first ?? Entity(displayName: "Preview Entity")

    return NavigationStack {
        PostFeedView(entity: entity)
    }
    .modelContainer(PreviewData.container)
}
