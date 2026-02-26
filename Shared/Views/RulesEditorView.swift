import SwiftUI
import SwiftData
import Receptacle

/// Edit display name, importance level, protection level, retention policy,
/// reply tone, and sub-rules for an Entity — all in one place.
struct RulesEditorView: View {
    @Bindable var entity: Entity
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Display Name", text: $entity.displayName)
                }

                Section("Importance & Protection") {
                    Picker("Importance", selection: $entity.importanceLevel) {
                        Text("Normal").tag(ImportanceLevel.normal)
                        Text("Important").tag(ImportanceLevel.important)
                        Text("Critical").tag(ImportanceLevel.critical)
                    }
                    Picker("Protection", selection: $entity.protectionLevel) {
                        Text("Protected — no delete actions").tag(ProtectionLevel.protected)
                        Text("Normal").tag(ProtectionLevel.normal)
                        Text("Apocalyptic — delete freely").tag(ProtectionLevel.apocalyptic)
                    }
                }

                Section("Retention") {
                    RetentionPolicyPicker(policy: $entity.retentionPolicy)
                }

                Section("Reply Tone") {
                    ReplyTonePicker(tone: $entity.replyTone)
                }

                Section("Sub-Rules") {
                    if entity.subRules.isEmpty {
                        Text("No sub-rules — entity policy applies to all items.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(entity.subRules.indices, id: \.self) { i in
                        SubRuleRow(rule: entity.subRules[i])
                    }
                    Button("Add Sub-Rule") {
                        // TODO Phase 1/2: present sub-rule creation sheet
                    }
                }
            }
            .navigationTitle("Edit Rules")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct RetentionPolicyPicker: View {
    @Binding var policy: RetentionPolicy

    var body: some View {
        // Simplified picker — full implementation in Phase 2
        Text(policy.displayName)
            .foregroundStyle(.secondary)
    }
}

struct ReplyTonePicker: View {
    @Binding var tone: ReplyTone

    var body: some View {
        Text(tone.displayName)
            .foregroundStyle(.secondary)
    }
}

struct SubRuleRow: View {
    let rule: SubRule

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(rule.matchType.rawValue): \"\(rule.pattern)\"")
                .font(.subheadline)
            Text("→ \(rule.action.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

extension ReplyTone {
    var displayName: String {
        switch self {
        case .formal: "Formal"
        case .casualClean: "Casual (clean)"
        case .friendly: "Friendly"
        case .custom(let prompt): "Custom: \(prompt.prefix(40))"
        }
    }
}
