// macOS app entry point.
// Included in the macOS Xcode target only — not in the SPM Receptacle library.

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

// MARK: - ContentView

struct ContentView: View {
    @State private var selectedEntity: Entity?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            EntityListView(selectedEntity: $selectedEntity)
                .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 320)
        } detail: {
            if let entity = selectedEntity {
                PostFeedView(entity: entity)
            } else {
                ContentUnavailableView(
                    "Select an entity",
                    systemImage: "tray",
                    description: Text("Choose a sender from the sidebar.")
                )
            }
        }
        .navigationTitle("Receptacle")
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    var body: some View {
        TabView {
            AIPermissionsPanel()
                .tabItem { Label("AI", systemImage: "brain") }
            RulesEditorView()
                .tabItem { Label("Rules", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 540, height: 440)
    }
}
#endif
