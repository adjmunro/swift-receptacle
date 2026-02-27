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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Display Name", text: $contact.displayName)
                    Picker("Type", selection: $contact.type) {
                        ForEach(ContactType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
                Section("Source Identifiers") {
                    ForEach(contact.sourceIdentifiers.indices, id: \.self) { i in
                        HStack {
                            Text(contact.sourceIdentifiers[i].type.rawValue)
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)
                            Text(contact.sourceIdentifiers[i].value)
                        }
                    }
                }
            }
            .navigationTitle("Edit Contact")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
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
