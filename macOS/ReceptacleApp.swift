// macOS app entry point.
// Included in the macOS Xcode target only — not in the SPM Receptacle library.

#if os(macOS)
import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct ReceptacleApp: App {

    init() {
        // Configure Google Sign-In SDK on launch if we have a saved client ID.
        // The URL scheme (GOOGLE_REVERSED_CLIENT_ID) must be set in Build Settings
        // and the reversed ID registered in macOS/Info.plist CFBundleURLSchemes.
        if let clientId = UserDefaults.standard.string(forKey: "google.oauth.clientId"),
           !clientId.isEmpty {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Pass incoming URLs to GIDSignIn for the OAuth2 callback.
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
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
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            EntityListView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 320)
        } detail: {
            ContentUnavailableView(
                "Select an entity",
                systemImage: "tray",
                description: Text("Choose a sender from the sidebar.")
            )
        }
        .navigationTitle("Receptacle")
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    var body: some View {
        TabView {
            AccountsSettingsView()
                .tabItem { Label("Accounts", systemImage: "envelope.stack") }

            AIPermissionsPanel()
                .tabItem { Label("AI", systemImage: "brain") }

            // RulesEditorView is per-entity — accessed from the entity list, not global settings.
            Text("Select an entity from the Inbox sidebar to edit its rules.")
                .foregroundStyle(.secondary)
                .padding()
                .tabItem { Label("Rules", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 540, height: 520)
    }
}
#endif
