import SwiftUI
import SwiftData
import Receptacle

/// Browse and edit Contacts — display name, type, source identifiers,
/// and the linked Entity (importance, tone, retention).
struct ContactsManagerView: View {
    @Query(sort: \Contact.displayName) private var contacts: [Contact]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedContact: Contact?
    @State private var showingAddContact = false

    var filtered: [Contact] {
        // Feeds are managed separately in FeedsManagerView.
        let nonFeeds = contacts.filter { $0.type != .feed }
        guard !searchText.isEmpty else { return nonFeeds }
        return nonFeeds.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filtered, selection: $selectedContact) { contact in
            ContactRowView(contact: contact)
                .tag(contact)
        }
        .searchable(text: $searchText)
        .navigationTitle("Contacts")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddContact = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add a new contact")
            }
        }
        .sheet(item: $selectedContact) { contact in
            ContactDetailView(contact: contact)
        }
        .sheet(isPresented: $showingAddContact) {
            AddContactSheet()
        }
    }
}

// MARK: - AddContactSheet

private struct AddContactSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var contactType: ContactType = .person

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Display Name", text: $displayName)
                    Picker("Type", selection: $contactType) {
                        ForEach(ContactType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("Add Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let contact = Contact(
                            displayName: displayName.trimmingCharacters(in: .whitespaces),
                            type: contactType
                        )
                        modelContext.insert(contact)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - ContactRowView

struct ContactRowView: View {
    let contact: Contact

    var body: some View {
        HStack {
            Image(systemName: contact.type.systemImage)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text(contact.displayName)
                Text(contact.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - ContactDetailView

struct ContactDetailView: View {
    @Bindable var contact: Contact
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var associatedEntity: Entity? = nil

    private var navigationTitle: String {
        contact.type == .feed ? "Edit Feed" : "Edit Contact"
    }

    private var deleteLabel: String {
        contact.type == .feed ? "Remove Feed" : "Delete Contact"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Identity
                Section("Identity") {
                    TextField("Display Name", text: $contact.displayName, prompt: Text("Display Name"))
                    if contact.type == .feed {
                        LabeledContent("Type", value: contact.type.displayName)
                    } else {
                        Picker("Type", selection: $contact.type) {
                            ForEach(ContactType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                    }
                }

                // Source identifiers / Feed URL
                if !contact.sourceIdentifiers.isEmpty {
                    Section(contact.type == .feed ? "Feed URL" : "Source Identifiers") {
                        ForEach(contact.sourceIdentifiers.indices, id: \.self) { i in
                            LabeledContent(contact.sourceIdentifiers[i].type.rawValue.uppercased()) {
                                HStack(spacing: 6) {
                                    Text(contact.sourceIdentifiers[i].value)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                        .multilineTextAlignment(.trailing)

                                    Button {
                                        copyToClipboard(contact.sourceIdentifiers[i].value)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Copy to clipboard")
                                }
                            }
                        }
                    }
                }

                // Feed-specific settings (only when entity is loaded)
                if contact.type == .feed, let entity = associatedEntity {
                    FeedSettingsSection(entity: entity)
                }

                // Delete
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label(deleteLabel, systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                deleteLabel,
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(deleteLabel, role: .destructive) { deleteContact() }
            } message: {
                Text(contact.type == .feed
                    ? "This will remove the feed subscription and all its cached articles."
                    : "This will permanently delete this contact.")
            }
        }
        .onAppear { loadEntity() }
#if os(macOS)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 440)
#endif
    }

    private func copyToClipboard(_ string: String) {
#if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
#else
        UIPasteboard.general.string = string
#endif
    }

    private func loadEntity() {
        let cid = contact.id.uuidString
        associatedEntity = (try? modelContext.fetch(FetchDescriptor<Entity>()))?.first {
            $0.contactIds.contains(cid)
        }
    }

    private func deleteContact() {
        let contactIdStr = contact.id.uuidString
        if let entities = try? modelContext.fetch(FetchDescriptor<Entity>()) {
            for entity in entities where entity.contactIds.contains(contactIdStr) {
                entity.contactIds.removeAll { $0 == contactIdStr }
                if entity.contactIds.isEmpty {
                    let eid = entity.id.uuidString
                    let feedDesc = FetchDescriptor<FeedItem>(predicate: #Predicate { $0.entityId == eid })
                    (try? modelContext.fetch(feedDesc))?.forEach { modelContext.delete($0) }
                    let mailDesc = FetchDescriptor<EmailItem>(predicate: #Predicate { $0.entityId == eid })
                    (try? modelContext.fetch(mailDesc))?.forEach { modelContext.delete($0) }
                    modelContext.delete(entity)
                }
            }
        }
        modelContext.delete(contact)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - FeedSettingsSection

/// Edits the Entity fields that are meaningful for an RSS feed:
/// refresh cadence, retention policy, and priority.
private struct FeedSettingsSection: View {
    @Bindable var entity: Entity
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var retentionKind: RetentionKind = .keepLatest
    @State private var retentionCount: Int = 50

    var body: some View {
        Section("Feed Settings") {
            // Refresh cadence
            Picker("Refresh Every", selection: $entity.feedRefreshIntervalMinutes) {
                Text("15 minutes").tag(15)
                Text("30 minutes").tag(30)
                Text("1 hour").tag(60)
                Text("3 hours").tag(180)
                Text("6 hours").tag(360)
                Text("Daily").tag(1440)
            }

            // Retention policy — type picker
            Picker("Keep", selection: $retentionKind) {
                ForEach(RetentionKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .onChange(of: retentionKind) { _, new in
                entity.retentionPolicy = .make(kind: new, count: retentionCount)
            }

            // Associated count (shown only when the policy needs one)
            if retentionKind.needsCount {
                Stepper(
                    retentionKind == .keepLatest
                        ? "\(retentionCount) items"
                        : "\(retentionCount) days",
                    value: $retentionCount,
                    in: 1...9999
                )
                .onChange(of: retentionCount) { _, new in
                    entity.retentionPolicy = .make(kind: retentionKind, count: new)
                }
            }

            // Priority / importance
            Picker("Priority", selection: $entity.importanceLevel) {
                Text("Normal").tag(ImportanceLevel.normal)
                Text("Important").tag(ImportanceLevel.important)
                Text("Critical").tag(ImportanceLevel.critical)
            }
        }

        TagPickerSection(tagIds: $entity.tagIds, allTags: allTags)
        .onAppear {
            retentionKind  = RetentionKind(from: entity.retentionPolicy)
            retentionCount = entity.retentionPolicy.associatedCount
        }
    }
}

// MARK: - RetentionPolicy editing helpers

/// Flat enum mirroring `RetentionPolicy` cases without associated values,
/// used to drive a Picker in the UI.
private enum RetentionKind: String, CaseIterable {
    case keepAll, keepLatest, keepDays, autoArchive, autoDelete

    init(from policy: RetentionPolicy) {
        switch policy {
        case .keepAll:     self = .keepAll
        case .keepLatest:  self = .keepLatest
        case .keepDays:    self = .keepDays
        case .autoArchive: self = .autoArchive
        case .autoDelete:  self = .autoDelete
        }
    }

    var displayName: String {
        switch self {
        case .keepAll:     return "Keep all"
        case .keepLatest:  return "Keep latest N"
        case .keepDays:    return "Keep N days"
        case .autoArchive: return "Auto-archive"
        case .autoDelete:  return "Auto-delete"
        }
    }

    /// Whether this kind requires a numeric count to be meaningful.
    var needsCount: Bool { self == .keepLatest || self == .keepDays }
}

private extension RetentionPolicy {
    /// Returns the associated integer for `.keepLatest` / `.keepDays`, defaulting to 50.
    var associatedCount: Int {
        switch self {
        case .keepLatest(let n), .keepDays(let n): return n
        default: return 50
        }
    }

    /// Reconstructs a `RetentionPolicy` from a `RetentionKind` + count.
    static func make(kind: RetentionKind, count: Int) -> RetentionPolicy {
        switch kind {
        case .keepAll:     return .keepAll
        case .keepLatest:  return .keepLatest(count)
        case .keepDays:    return .keepDays(count)
        case .autoArchive: return .autoArchive
        case .autoDelete:  return .autoDelete
        }
    }
}

// MARK: - ContactType extensions

extension ContactType {
    var displayName: String {
        switch self {
        case .person: "Person"
        case .organization: "Organisation"
        case .newsletter: "Newsletter"
        case .transactional: "Transactional"
        case .automated: "Automated"
        case .feed: "RSS Feed"
        }
    }

    var systemImage: String {
        switch self {
        case .person: "person"
        case .organization: "building.2"
        case .newsletter: "newspaper"
        case .transactional: "cart"
        case .automated: "gear"
        case .feed: "dot.radiowaves.up.forward"
        }
    }
}
