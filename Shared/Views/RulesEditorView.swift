import SwiftUI
import SwiftData
import Receptacle

/// Edit display name, importance level, protection level, retention policy,
/// reply tone, and sub-rules for an Entity — all in one place.
struct RulesEditorView: View {
    @Bindable var entity: Entity
    @Environment(\.dismiss) private var dismiss

    @State private var showAddSubRule = false

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
                    .onDelete { offsets in
                        entity.subRules.remove(atOffsets: offsets)
                    }
                    Button("Add Sub-Rule") {
                        showAddSubRule = true
                    }
                }
            }
            .navigationTitle("Edit Rules")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddSubRule) {
                AddSubRuleSheet { newRule in
                    entity.subRules.append(newRule)
                }
            }
        }
    }
}

// MARK: - RetentionPolicyPicker

struct RetentionPolicyPicker: View {
    @Binding var policy: RetentionPolicy

    /// Tag-safe case enum for the Picker.
    private enum PolicyCase: String, CaseIterable, Identifiable {
        case keepAll, keepLatest, keepDays, autoArchive, autoDelete
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .keepAll:     return "Keep all"
            case .keepLatest:  return "Keep latest N"
            case .keepDays:    return "Keep N days"
            case .autoArchive: return "Auto-archive"
            case .autoDelete:  return "Auto-delete"
            }
        }
    }

    private var selectedCase: PolicyCase {
        switch policy {
        case .keepAll:     return .keepAll
        case .keepLatest:  return .keepLatest
        case .keepDays:    return .keepDays
        case .autoArchive: return .autoArchive
        case .autoDelete:  return .autoDelete
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Policy", selection: Binding(
                get: { selectedCase },
                set: { newCase in
                    switch newCase {
                    case .keepAll:
                        policy = .keepAll
                    case .keepLatest:
                        if case .keepLatest(let n) = policy { policy = .keepLatest(n) }
                        else { policy = .keepLatest(5) }
                    case .keepDays:
                        if case .keepDays(let n) = policy { policy = .keepDays(n) }
                        else { policy = .keepDays(30) }
                    case .autoArchive:
                        policy = .autoArchive
                    case .autoDelete:
                        policy = .autoDelete
                    }
                }
            )) {
                ForEach(PolicyCase.allCases) { c in
                    Text(c.displayName).tag(c)
                }
            }
            .pickerStyle(.menu)

            if case .keepLatest(let n) = policy {
                HStack {
                    Text("Keep latest")
                    TextField("", value: Binding(
                        get: { n },
                        set: { policy = .keepLatest($0) }
                    ), format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    Text("items")
                    Stepper("", value: Binding(
                        get: { n },
                        set: { policy = .keepLatest($0) }
                    ), in: 1...1000)
                    .labelsHidden()
                }
            }
            if case .keepDays(let n) = policy {
                HStack {
                    Text("Keep")
                    TextField("", value: Binding(
                        get: { n },
                        set: { policy = .keepDays($0) }
                    ), format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    Text("days")
                    Stepper("", value: Binding(
                        get: { n },
                        set: { policy = .keepDays($0) }
                    ), in: 1...3650)
                    .labelsHidden()
                }
            }
        }
    }
}

// MARK: - ReplyTonePicker

struct ReplyTonePicker: View {
    @Binding var tone: ReplyTone

    private enum ToneCase: String, CaseIterable, Identifiable {
        case formal, casualClean, friendly, custom
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .formal:      return "Formal"
            case .casualClean: return "Casual (clean)"
            case .friendly:    return "Friendly"
            case .custom:      return "Custom"
            }
        }
    }

    private var selectedCase: ToneCase {
        switch tone {
        case .formal:      return .formal
        case .casualClean: return .casualClean
        case .friendly:    return .friendly
        case .custom:      return .custom
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Tone", selection: Binding(
                get: { selectedCase },
                set: { newCase in
                    switch newCase {
                    case .formal:      tone = .formal
                    case .casualClean: tone = .casualClean
                    case .friendly:    tone = .friendly
                    case .custom:
                        if case .custom(let p) = tone { tone = .custom(prompt: p) }
                        else { tone = .custom(prompt: "") }
                    }
                }
            )) {
                ForEach(ToneCase.allCases) { c in
                    Text(c.displayName).tag(c)
                }
            }
            .pickerStyle(.menu)

            if case .custom(let prompt) = tone {
                TextField("Custom prompt", text: Binding(
                    get: { prompt },
                    set: { tone = .custom(prompt: $0) }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }
}

// MARK: - SubRuleRow

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

// MARK: - AddSubRuleSheet

/// Sheet for creating a new `SubRule` with MatchType, pattern, and retention policy inputs.
struct AddSubRuleSheet: View {
    var onAdd: (SubRule) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var matchType: MatchType = .subjectContains
    @State private var pattern = ""
    @State private var retentionPolicy: RetentionPolicy = .keepAll

    var body: some View {
        NavigationStack {
            Form {
                Section("Match Condition") {
                    Picker("Match on", selection: $matchType) {
                        ForEach(MatchType.allCases, id: \.self) { mt in
                            Text(mt.rawValue).tag(mt)
                        }
                    }
                    TextField("Pattern (e.g. \"Order\", \"Receipt\")", text: $pattern)
                }

                Section("Override Action") {
                    RetentionPolicyPicker(policy: $retentionPolicy)
                }
            }
            .navigationTitle("Add Sub-Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !pattern.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        onAdd(SubRule(
                            matchType: matchType,
                            pattern: pattern.trimmingCharacters(in: .whitespaces),
                            action: retentionPolicy
                        ))
                        dismiss()
                    }
                    .disabled(pattern.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - ReplyTone display extension

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
