// iOS app entry point
// This file is included in the iOS Xcode target only — not in the SPM Receptacle library.

#if os(iOS)
import SwiftUI
import SwiftData

@main
struct ReceptacleApp: App {
    var body: some Scene {
        WindowGroup {
            IOSRootView()
        }
        .modelContainer(for: [
            Contact.self,
            Entity.self,
            EmailItem.self,
            FeedItem.self,
            AIPermission.self,
            Note.self,
            Tag.self,
            SavedLink.self,
            Project.self,
            KanbanColumn.self,
            TodoItem.self,
            SourceUsage.self,
        ])
    }
}

// MARK: - IOSRootView

/// Root navigation container for iOS.
///
/// Uses `NavigationStack` (push navigation) instead of macOS `NavigationSplitView`.
/// `EntityListView` rows are `NavigationLink(value:)` on iOS; `.navigationDestination`
/// here handles the actual push to `PostFeedView`.
///
/// Second-level navigation within PostFeedView (reply, notes, tags) uses
/// `.sheet` presentation — see `PostCardView` and `SidebarNoteView`.
struct IOSRootView: View {
    var body: some View {
        NavigationStack {
            EntityListView()
                .navigationDestination(for: Entity.self) { entity in
                    PostFeedView(entity: entity)
                }
        }
    }
}
#endif
