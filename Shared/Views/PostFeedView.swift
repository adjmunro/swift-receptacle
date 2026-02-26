import SwiftUI
import SwiftData

/// Per-entity view: source tabs at the top + scrollable post-card feed.
///
/// Source tabs: one per source type the entity has items in (email, RSS, etc.)
/// Each tab shows an unread-count dot.
/// Tab ordering (computed on first tap):
///   - Tabs with unreads → sorted by unread count descending
///   - No unreads → sorted by SourceUsage.viewCount descending
struct PostFeedView: View {
    let entity: Entity
    @State private var selectedSource: SourceType? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Source tab bar — Phase 2 placeholder
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    SourceTabButton(label: "All", isSelected: selectedSource == nil) {
                        selectedSource = nil
                    }
                    // TODO Phase 2: enumerate actual sources for this entity
                }
                .padding(.horizontal)
            }
            .frame(height: 44)

            Divider()

            // Post card feed
            ScrollView {
                LazyVStack(spacing: 12) {
                    // TODO Phase 2: fetch EmailItem/FeedItem from SwiftData filtered by entityId
                    Text("No items yet")
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .padding()
            }
        }
        .navigationTitle(entity.displayName)
    }
}

struct SourceTabButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
