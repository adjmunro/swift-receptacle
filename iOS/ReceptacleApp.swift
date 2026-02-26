// iOS app entry point
// This file is included in the iOS Xcode target only — not in the SPM Receptacle library.
// Full implementation: Phase 13.

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

struct IOSRootView: View {
    var body: some View {
        NavigationStack {
            EntityListView()
        }
    }
}
#endif
