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
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter {
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

    private var navigationTitle: String {
        contact.type == .feed ? "Edit Feed" : "Edit Contact"
    }

    private var deleteLabel: String {
        contact.type == .feed ? "Remove Feed" : "Delete Contact"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Display Name", text: $contact.displayName, prompt: Text("Display Name"))
                    Picker("Type", selection: $contact.type) {
                        ForEach(ContactType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                if !contact.sourceIdentifiers.isEmpty {
                    Section(contact.type == .feed ? "Feed URL" : "Source Identifiers") {
                        ForEach(contact.sourceIdentifiers.indices, id: \.self) { i in
                            LabeledContent(contact.sourceIdentifiers[i].type.rawValue.uppercased()) {
                                Text(contact.sourceIdentifiers[i].value)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }

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
                    Button("Done") { dismiss() }
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
#if os(macOS)
        .frame(minWidth: 420, idealWidth: 460, minHeight: 320)
#endif
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
