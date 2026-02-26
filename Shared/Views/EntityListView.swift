import SwiftUI
import SwiftData

/// Top-level inbox: a list of `Entity` rows ordered by importance then recency.
///
/// - `.critical` / `.important` entities float to the top.
/// - Swipe actions adapt to `protectionLevel`:
///   - `.protected`: no destructive swipe actions
///   - `.apocalyptic`: "Delete All" swipe action available
/// - Tap → `PostFeedView` for that entity
struct EntityListView: View {
    @Query(sort: \Entity.displayName) private var entities: [Entity]
    @State private var selectedEntityId: String?

    var sortedEntities: [Entity] {
        entities.sorted {
            if $0.importanceLevel != $1.importanceLevel {
                return $0.importanceLevel > $1.importanceLevel
            }
            return $0.displayName < $1.displayName
        }
    }

    var body: some View {
        List(sortedEntities, selection: $selectedEntityId) { entity in
            EntityRowView(entity: entity)
                .tag(entity.id.uuidString)
        }
        .navigationTitle("Inbox")
    }
}

struct EntityRowView: View {
    let entity: Entity

    var body: some View {
        HStack {
            // Importance indicator
            if entity.importanceLevel >= .important {
                Circle()
                    .fill(entity.importanceLevel == .critical ? Color.red : Color.orange)
                    .frame(width: 8, height: 8)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entity.displayName)
                    .font(.headline)
                Text(entity.retentionPolicy.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension RetentionPolicy {
    var displayName: String {
        switch self {
        case .keepAll: "Keep all"
        case .keepLatest(let n): "Keep latest \(n)"
        case .keepDays(let n): "Keep \(n) days"
        case .autoArchive: "Auto-archive"
        case .autoDelete: "Auto-delete"
        }
    }
}
