import SwiftUI
import SwiftData

// MARK: - TagPickerSection

/// A Form `Section` showing selected tags as removable chips, plus a button
/// to open `TagPickerSheet` for adding more.
///
/// Usage (inside a `Form`):
/// ```swift
/// TagPickerSection(tagIds: $entity.tagIds, allTags: allTags)
/// ```
struct TagPickerSection: View {
    @Binding var tagIds: [String]
    let allTags: [Tag]

    @State private var showPicker = false

    private var selectedTags: [Tag] {
        allTags.filter { tagIds.contains($0.id.uuidString) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        Section("Tags") {
            if selectedTags.isEmpty {
                Button {
                    showPicker = true
                } label: {
                    Label("Add Tags…", systemImage: "tag.badge.plus")
                }
            } else {
                // Horizontal scrolling row of chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(selectedTags) { tag in
                            TagChip(name: tag.name) {
                                tagIds.removeAll { $0 == tag.id.uuidString }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                Button {
                    showPicker = true
                } label: {
                    Label("Add Tag…", systemImage: "plus")
                        .font(.callout)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            TagPickerSheet(tagIds: $tagIds, allTags: allTags)
        }
    }
}

// MARK: - TagChip

/// A pill-shaped tag label with an inline ✕ remove button.
struct TagChip: View {
    let name: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 3) {
            Text(name)
                .font(.caption)
            if let onRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.15), in: Capsule())
        .foregroundStyle(Color.accentColor)
    }
}

// MARK: - TagPickerSheet

/// Modal list of all tags with checkmarks; toggling adds/removes from `tagIds`.
private struct TagPickerSheet: View {
    @Binding var tagIds: [String]
    let allTags: [Tag]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if allTags.isEmpty {
                    ContentUnavailableView(
                        "No Tags",
                        systemImage: "tag.slash",
                        description: Text("Create tags in the Tag Browser first.")
                    )
                } else {
                    List {
                        ForEach(allTags) { tag in
                            let isOn = tagIds.contains(tag.id.uuidString)
                            Button {
                                if isOn {
                                    tagIds.removeAll { $0 == tag.id.uuidString }
                                } else {
                                    tagIds.append(tag.id.uuidString)
                                }
                            } label: {
                                HStack {
                                    Label(tag.name, systemImage: "tag")
                                    Spacer()
                                    if isOn {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Select Tags")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 300, idealWidth: 340, minHeight: 280)
#endif
    }
}
