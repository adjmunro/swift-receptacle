import SwiftUI
import SwiftData

/// Shows and edits AI permission settings per provider, feature, and entity.
struct AIPermissionsPanel: View {
    @Query private var permissions: [AIPermission]
    @Environment(\.modelContext) private var context

    let providers: [(id: String, name: String, isLocal: Bool)] = [
        ("local-whisper", "On-Device Whisper", true),
        ("openai", "OpenAI (ChatGPT)", false),
        ("claude", "Anthropic Claude", false),
    ]

    var body: some View {
        Form {
            ForEach(providers, id: \.id) { provider in
                Section {
                    ForEach(AIFeature.allCases, id: \.self) { feature in
                        PermissionRow(
                            providerId: provider.id,
                            feature: feature,
                            permissions: permissions,
                            context: context
                        )
                    }
                } header: {
                    HStack {
                        Label(provider.name,
                              systemImage: provider.isLocal ? "iphone" : "cloud")
                        if !provider.isLocal {
                            Spacer()
                            Text("Cloud — opt-in required")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle("AI Permissions")
    }
}

struct PermissionRow: View {
    let providerId: String
    let feature: AIFeature
    let permissions: [AIPermission]
    let context: ModelContext

    var currentScope: AIScope {
        permissions.first {
            $0.providerId == providerId &&
            $0.feature == feature &&
            $0.entityId == nil
        }?.scope ?? .askEachTime
    }

    var body: some View {
        Picker(feature.displayName, selection: Binding(
            get: { currentScope },
            set: { newScope in
                if let existing = permissions.first(where: {
                    $0.providerId == providerId && $0.feature == feature && $0.entityId == nil
                }) {
                    existing.scope = newScope
                } else {
                    let p = AIPermission(providerId: providerId, feature: feature, scope: newScope)
                    context.insert(p)
                }
            }
        )) {
            Text("Always").tag(AIScope.always)
            Text("Ask each time").tag(AIScope.askEachTime)
            Text("Never").tag(AIScope.never)
        }
    }
}

extension AIFeature {
    var displayName: String {
        switch self {
        case .summarise: "Summarise"
        case .reframeTone: "Reframe Tone"
        case .transcribe: "Transcribe Voice"
        case .privacySummary: "Privacy Policy Summary"
        case .tagSuggest: "Suggest Tags"
        case .eventParse: "Parse Events"
        }
    }
}
