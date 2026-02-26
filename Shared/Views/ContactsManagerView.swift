import SwiftUI
import SwiftData
import Receptacle

/// Browse and edit Contacts — display name, type, source identifiers,
/// and the linked Entity (importance, tone, retention).
struct ContactsManagerView: View {
    @Query(sort: \Contact.displayName) private var contacts: [Contact]
    @State private var searchText = ""
    @State private var selectedContact: Contact?

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
        .sheet(item: $selectedContact) { contact in
            ContactDetailView(contact: contact)
        }
    }
}

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
