import SwiftUI

/// A single item rendered as a post card within PostFeedView.
///
/// Email cards: HTML via HTMLBodyView; quoted sections collapsed by default.
/// Reply threads nested as sub-cards.
/// `.important`/`.critical` items show a visual indicator; deletion double-confirms.
struct PostCardView: View {
    let itemId: String
    let entityId: String
    let importanceLevel: ImportanceLevel
    let date: Date
    let summary: String

    @State private var isExpanded = true
    @State private var showQuoted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                if importanceLevel >= .important {
                    Image(systemName: importanceLevel == .critical ? "exclamationmark.2" : "exclamationmark")
                        .foregroundStyle(importanceLevel == .critical ? .red : .orange)
                        .font(.caption)
                }
                Spacer()
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                // Body — Phase 7: replace with HTMLBodyView
                Text(summary)
                    .font(.body)
                    .lineLimit(nil)

                // Quoted content toggle — Phase 6
                Button {
                    showQuoted.toggle()
                } label: {
                    Text(showQuoted ? "Hide quoted text" : "Show quoted text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(
#if os(macOS)
            .windowBackground
#else
            .secondarySystemBackground
#endif
        ))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
