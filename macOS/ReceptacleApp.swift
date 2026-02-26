// macOS app entry point
// This file is included in the macOS Xcode target only — not in the SPM Receptacle library.
// Full implementation: Phase 2 (navigation chrome) + Phase 13 (iOS parity).

#if os(macOS)
import SwiftUI
import SwiftData

@main
struct ReceptacleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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

        Settings {
            SettingsView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            EntityListView()
        } detail: {
            Text("Select an entity")
                .foregroundStyle(.secondary)
        }
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            AIPermissionsPanel()
                .tabItem { Label("AI", systemImage: "brain") }
        }
        .frame(width: 500, height: 400)
    }
}
#endif
