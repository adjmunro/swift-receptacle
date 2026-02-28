import SwiftUI
import SwiftData

// MARK: - TagPickerSection

struct TagPickerSection: View {
    @Binding var tagIds: [String]
    let allTags: [Tag]

    var body: some View {
        Section("Tags") {
            TagTokenInput(tagIds: $tagIds, allTags: allTags)
        }
    }
}

// MARK: - TagTokenInput

/// Chips + inline cursor in one wrapping field.
/// Space / Return commit the current token; Tab accepts the ghost-text hint.
private struct TagTokenInput: View {
    @Binding var tagIds: [String]
    let allTags: [Tag]

    @Environment(\.modelContext) private var modelContext
    @State private var input = ""
    @FocusState private var focused: Bool

    // MARK: Derived

    private var selectedTags: [Tag] {
        allTags.filter { tagIds.contains($0.id.uuidString) }
            .sorted { tagPath($0) < tagPath($1) }
    }

    private var topSuggestion: Tag? {
        let q = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return nil }
        return allTags
            .filter { !tagIds.contains($0.id.uuidString) }
            .filter { tagPath($0).lowercased().hasPrefix(q) }
            .sorted { tagPath($0) < tagPath($1) }
            .first
    }

    /// The grey suffix text shown after the cursor, e.g. "ch" when typing "te" → "tech".
    private var ghostSuffix: String? {
        guard !input.isEmpty, let top = topSuggestion else { return nil }
        let path = tagPath(top)
        guard path.count > input.count else { return nil }
        return String(path.dropFirst(input.count))
    }

    // MARK: Body

    var body: some View {
        // TagFlowLayout places chips first; the ZStack (cursor row) is always last and
        // gets whatever width remains on its row.
        TagFlowLayout(spacing: 6) {
            ForEach(selectedTags) { tag in
                TagChip(name: tagPath(tag)) {
                    tagIds.removeAll { $0 == tag.id.uuidString }
                }
            }

            // Cursor: ZStack lets ghost text sit behind the live TextField.
            // frame(maxWidth: .infinity) signals to TagFlowLayout to fill the row.
            ZStack(alignment: .leading) {
                // Ghost hint: invisible spacer matching typed-text width, then grey suffix.
                if let suffix = ghostSuffix {
                    HStack(spacing: 0) {
                        Text(input).opacity(0)
                        Text(suffix).foregroundStyle(.secondary.opacity(0.45))
                    }
                    .font(.body)
                    .allowsHitTesting(false)
                }

                TextField("", text: $input)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .frame(maxWidth: .infinity)
                    .focused($focused)
                    .onSubmit { acceptOrCommit() }
                    .onChange(of: input) { _, new in
                        guard new.last == " " else { return }
                        let token = String(new.dropLast())
                            .trimmingCharacters(in: .whitespaces)
                        if !token.isEmpty { commit(token) }
                        input = ""
                    }
                    .onKeyPress(.tab) {
                        guard let top = topSuggestion else { return .ignored }
                        commit(tagPath(top))
                        input = ""
                        return .handled
                    }
            }
            .frame(maxWidth: .infinity) // last item in flow: fill remaining row width
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    // MARK: Helpers

    private func acceptOrCommit() {
        if let top = topSuggestion {
            commit(tagPath(top))
        } else {
            let token = input.trimmingCharacters(in: .whitespaces)
            if !token.isEmpty { commit(token) }
        }
        input = ""
    }

    private func tagPath(_ tag: Tag) -> String {
        var parts = [tag.name]
        var pid = tag.parentTagId
        while let id = pid, let parent = allTags.first(where: { $0.id.uuidString == id }) {
            parts.insert(parent.name, at: 0)
            pid = parent.parentTagId
        }
        return parts.joined(separator: "/")
    }

    private func add(_ tag: Tag) {
        let id = tag.id.uuidString
        if !tagIds.contains(id) { tagIds.append(id) }
    }

    private func commit(_ token: String) {
        let parts = token
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return }

        var parentId: String? = nil
        var pending: [Tag] = []
        var leaf: Tag? = nil

        for name in parts {
            let pool = allTags + pending
            if let existing = pool.first(where: {
                $0.name.lowercased() == name.lowercased() && $0.parentTagId == parentId
            }) {
                leaf = existing
                parentId = existing.id.uuidString
            } else {
                let tag = Tag(name: name, parentTagId: parentId)
                modelContext.insert(tag)
                pending.append(tag)
                leaf = tag
                parentId = tag.id.uuidString
            }
        }

        if let tag = leaf { add(tag) }
    }
}

// MARK: - TagFlowLayout

/// Left-to-right wrapping layout.
/// The last subview (the text cursor) is always expanded to fill the remaining row width.
private struct TagFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0

        for (i, view) in subviews.enumerated() {
            let isLast = i == subviews.count - 1
            var size = view.sizeThatFits(.unspecified)
            // Enforce a minimum presence for the cursor item so it doesn't wrap too eagerly.
            if isLast { size.width = max(size.width, 80) }

            if x > 0, x + size.width > maxW {
                y += rowH + spacing; x = 0; rowH = 0
            }
            rowH = max(rowH, size.height)
            // Don't advance x for the last item — it fills remaining space.
            if !isLast { x += size.width + spacing }
        }
        return CGSize(width: maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0

        for (i, view) in subviews.enumerated() {
            let isLast = i == subviews.count - 1
            var size = view.sizeThatFits(.unspecified)
            if isLast { size.width = max(size.width, 80) }

            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowH + spacing; x = bounds.minX; rowH = 0
            }

            // Last item: stretch to fill whatever width remains on this row.
            let w = isLast ? max(size.width, bounds.maxX - x) : size.width
            view.place(
                at: CGPoint(x: x, y: y),   // top-align; no vertical centering
                anchor: .topLeading,
                proposal: ProposedViewSize(width: w, height: size.height)
            )
            rowH = max(rowH, size.height)
            if !isLast { x += size.width + spacing }
        }
    }
}

// MARK: - TagChip

/// A pill-shaped tag label with an optional inline ✕ remove button.
struct TagChip: View {
    let name: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 3) {
            Text(name).font(.caption)
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
