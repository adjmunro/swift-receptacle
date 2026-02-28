import SwiftUI
import SwiftData
import Receptacle

// MARK: - EntityListView

/// Top-level inbox: a list of Entity rows ordered by importance then name.
///
/// Ordering rules (via `EntitySortKey`):
///   - `.critical` / `.important` entities float to the top
///   - Within the same importance level, alphabetical by displayName
///
/// Swipe actions are gated by `protectionLevel`:
///   - `.protected`   → no destructive actions
///   - `.normal`      → trailing "Archive all" action
///   - `.apocalyptic` → leading "Delete All" action (red, destructive)
///
/// ## Platform differences
/// - **macOS**: `NavigationLink(value:)` rows + `.navigationDestination` drives the
///   `NavigationSplitView` detail pane.
/// - **iOS**: Same `NavigationLink(value:)` rows; `IOSRootView`'s `NavigationStack`
///   provides `.navigationDestination` to push `PostFeedView`.
struct EntityListView: View {
    @Query private var entities: [Entity]

    @State private var showingFeeds    = false
    @State private var showingContacts = false
    @Environment(\.modelContext) private var modelContext

    // MARK: Computed

    var sortedEntities: [Entity] {
        entities.sorted {
            let lk = EntitySortKey(importanceLevel: $0.importanceLevel, displayName: $0.displayName)
            let rk = EntitySortKey(importanceLevel: $1.importanceLevel, displayName: $1.displayName)
            return lk < rk
        }
    }

    // MARK: Body

    var body: some View {
        List(sortedEntities) { entity in
            NavigationLink(value: entity) {
                EntityRowView(entity: entity)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if entity.protectionLevel != .protected {
                    Button {
                        // Phase 3: call IMAPSource.archive for all items
                    } label: {
                        Label("Archive All", systemImage: "archivebox")
                    }
                    .tint(.orange)
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                if entity.protectionLevel == .apocalyptic {
                    Button(role: .destructive) {
                        // Phase 3: delete all items for this entity
                    } label: {
                        Label("Delete All", systemImage: "trash.fill")
                    }
                }
            }
        }
#if os(macOS)
        .navigationDestination(for: Entity.self) { entity in
            PostFeedView(entity: entity)
        }
#endif
        .navigationTitle("Inbox")
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomActionBar(
                showingFeeds: $showingFeeds,
                showingContacts: $showingContacts
            )
        }
        .sheet(isPresented: $showingFeeds) {
            NavigationStack {
                FeedsManagerView()
            }
#if os(macOS)
            .frame(minWidth: 500, idealWidth: 560, minHeight: 400)
#endif
        }
        .sheet(isPresented: $showingContacts) {
            NavigationStack {
                ContactsManagerView()
            }
#if os(macOS)
            .frame(minWidth: 500, idealWidth: 560, minHeight: 400)
#endif
        }
        .task {
            await FeedSyncService.sync(context: modelContext)
        }
    }
}

// MARK: - BottomActionBar

private struct BottomActionBar: View {
    @Binding var showingFeeds: Bool
    @Binding var showingContacts: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                Button {
                    showingFeeds = true
                } label: {
                    Label("Feeds", systemImage: "dot.radiowaves.up.forward")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Manage RSS, Atom, and JSON Feed subscriptions")

                Divider()
                    .frame(height: 20)

                Button {
                    showingContacts = true
                } label: {
                    Label("Contacts", systemImage: "person.2")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Browse and edit contacts")
            }
            .frame(height: 30)
            .padding(.horizontal)
        }
        .background(.bar)
    }
}

// MARK: - EntityRowView

struct EntityRowView: View {
    let entity: Entity

    var body: some View {
        HStack(spacing: 10) {
            // Importance indicator dot
            importanceDot

            VStack(alignment: .leading, spacing: 2) {
                Text(entity.displayName)
                    .font(.headline)

                HStack(spacing: 6) {
                    Text(entity.retentionPolicy.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if entity.protectionLevel == .protected {
                        Label("Protected", systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .labelStyle(.iconOnly)
                    } else if entity.protectionLevel == .apocalyptic {
                        Label("Ephemeral", systemImage: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .labelStyle(.iconOnly)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var importanceDot: some View {
        switch entity.importanceLevel {
        case .critical:
            Circle()
                .fill(Color.red)
                .frame(width: 9, height: 9)
        case .important:
            Circle()
                .fill(Color.orange)
                .frame(width: 9, height: 9)
        case .normal:
            Color.clear
                .frame(width: 9, height: 9)
        }
    }
}

// MARK: - Preview

#Preview("Entity List") {
    NavigationSplitView {
        EntityListView()
            .navigationTitle("Inbox")
    } detail: {
        Text("Select an entity")
            .foregroundStyle(.secondary)
    }
    .modelContainer(PreviewData.container)
}
