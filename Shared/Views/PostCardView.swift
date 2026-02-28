import SwiftUI
import SwiftData
import Receptacle

// MARK: - PostCardView

/// A single item rendered as a post-card within PostFeedView.
///
/// - Importance indicator (red/orange icon) for .critical/.important items
/// - Collapsed/expanded toggle (chevron)
/// - Body: plain-text summary until Phase 7 (HTMLBodyView)
/// - Quoted-text toggle placeholder (implemented in Phase 6)
/// - Reply button — opens VoiceReplyView via `onReply` callback
/// - Archive/delete wired to SwiftData model via `modelContext`
struct PostCardView: View {
    let item: PostCardItem
    let entity: Entity

    /// Called when the user taps Reply — parent presents VoiceReplyView.
    var onReply: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var isExpanded: Bool = true
    @State private var showQuoted: Bool = false
    @State private var showDeleteConfirm: Bool = false

    // Quoted-range detection — computed once per item.
    private let detector = QuotedRangeDetector()
    private var hasQuotedContent: Bool { detector.hasQuotedContent(in: item.summary) }
    private var collapsedBody: String  { detector.collapsedText(for: item.summary) }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.horizontal, 14)
                .padding(.top, 12)

            if isExpanded {
                Divider().padding(.vertical, 8)
                bodyContent
                    .padding(.horizontal, 14)
                actionBar
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            } else {
                Spacer().frame(height: 12)
            }
        }
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(importanceBorderColor, lineWidth: importanceBorderWidth)
        )
        .confirmationDialog(
            "Delete this item?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                performDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This item is marked \(item.importanceLevel == .critical ? "critical" : "important"). Are you sure?")
        }
    }

    // MARK: Subviews

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // Importance icon
            importanceIcon

            // Title / subject
            VStack(alignment: .leading, spacing: 2) {
                if let title = item.title {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                }
                Text(item.date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Unread dot
            if !item.isRead {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            }

            // Source badge
            Text(item.sourceType.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12), in: Capsule())

            // Expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var importanceIcon: some View {
        switch item.importanceLevel {
        case .critical:
            Image(systemName: "exclamationmark.2")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.red)
        case .important:
            Image(systemName: "exclamationmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)
        case .normal:
            EmptyView()
        }
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let html = item.contentHTML {
                HTMLTextView(html: html)
            } else {
                Text(showQuoted ? item.summary : collapsedBody)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .animation(.easeInOut(duration: 0.15), value: showQuoted)

                if hasQuotedContent {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { showQuoted.toggle() }
                    } label: {
                        Label(
                            showQuoted ? "Hide quoted text" : "Show quoted text",
                            systemImage: showQuoted ? "quote.bubble" : "quote.bubble.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 16) {
            Spacer()

            // Open link — only for feed items with a URL
            if let linkStr = item.linkURLString, let url = URL(string: linkStr) {
                Button {
                    openURL(url)
                } label: {
                    Label("Open", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Open article in browser")
            }

            // Reply — only for items with a reply-to address (email)
            if let replyTo = item.replyToAddress {
                Button {
                    onReply?()
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Reply to \(replyTo)")
            }

            // Archive — not for protected entities
            if entity.protectionLevel != .protected {
                Button {
                    performArchive()
                } label: {
                    Label("Archive", systemImage: "archivebox")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .tint(.orange)
            }

            // Delete — gated by protection level + importance
            if entity.protectionLevel != .protected {
                Button(role: .destructive) {
                    if item.importanceLevel > .normal {
                        showDeleteConfirm = true
                    } else {
                        performDelete()
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    /// Mark the item as archived in SwiftData.
    /// EmailItem: sets isArchived = true.
    /// FeedItem: sets isSaved = true (RSS "save" = archive equivalent).
    private func performArchive() {
        let itemId = item.id
        let emailPred = #Predicate<EmailItem> { $0.id == itemId }
        if let email = try? modelContext.fetch(FetchDescriptor(predicate: emailPred)).first {
            email.isArchived = true
            return
        }
        let feedPred = #Predicate<FeedItem> { $0.id == itemId }
        if let feed = try? modelContext.fetch(FetchDescriptor(predicate: feedPred)).first {
            feed.isSaved = true
        }
    }

    /// Mark the item as deleted in SwiftData.
    /// EmailItem: sets isDeleted = true (soft delete, filtered out of queries).
    /// FeedItem: hard-deleted from the store (no isDeleted flag).
    private func performDelete() {
        let itemId = item.id
        let emailPred = #Predicate<EmailItem> { $0.id == itemId }
        if let email = try? modelContext.fetch(FetchDescriptor(predicate: emailPred)).first {
            email.isDeleted = true
            return
        }
        let feedPred = #Predicate<FeedItem> { $0.id == itemId }
        if let feed = try? modelContext.fetch(FetchDescriptor(predicate: feedPred)).first {
            modelContext.delete(feed)
        }
    }

    // MARK: Appearance helpers

    private var cardBackground: Color {
#if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
#else
        return Color(uiColor: .secondarySystemBackground)
#endif
    }

    private var importanceBorderColor: Color {
        switch item.importanceLevel {
        case .critical:  return .red.opacity(0.4)
        case .important: return .orange.opacity(0.3)
        case .normal:    return .clear
        }
    }

    private var importanceBorderWidth: CGFloat {
        item.importanceLevel > .normal ? 1.5 : 0
    }
}

// MARK: - HTMLTextView

/// Renders an HTML string as a SwiftUI `Text` using `NSAttributedString`.
/// Conversion is async (WebKit-backed) so a plain-text fallback shows first.
private struct HTMLTextView: View {
    let html: String
    @State private var attributed: AttributedString?

    var body: some View {
        Group {
            if let attributed {
                Text(attributed)
                    .textSelection(.enabled)
            } else {
                Text(html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
        .task(id: html) { attributed = await Self.parse(html) }
    }

    @MainActor
    private static func parse(_ html: String) async -> AttributedString? {
        let styled = """
        <html><head><meta charset="utf-8"><style>
        body { font-family: -apple-system; font-size: 14px; margin: 0; }
        pre, code { font-size: 12px; }
        img { display: none; }
        </style></head><body>\(html)</body></html>
        """
        guard let data = styled.data(using: .utf8),
              let ns = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              )
        else { return nil }
        return AttributedString(ns)
    }
}

// MARK: - Preview

#Preview("Email card — important") {
    let item = PostCardItem(
        id: "p1",
        date: Date().addingTimeInterval(-3_600),
        summary: "Your ISA rate has changed from 4.5% to 4.2% effective 1 March 2026.",
        title: "Your savings rates have changed",
        importanceLevel: .critical,
        sourceType: .email,
        isRead: false,
        entityId: "e1",
        replyToAddress: "alerts@bank.example",
        linkURLString: nil,
        contentHTML: nil
    )
    let entity = Entity(
        displayName: "Bank Alerts",
        protectionLevel: .protected,
        retentionPolicy: .keepAll
    )
    PostCardView(item: item, entity: entity)
        .padding()
        .modelContainer(for: Entity.self, inMemory: true)
}

#Preview("Feed card — normal") {
    let item = PostCardItem(
        id: "p2",
        date: Date().addingTimeInterval(-43_200),
        summary: "The Swift team is pleased to announce Swift 6.2, featuring improved macros and new standard library additions.",
        title: "Swift 6.2 Released",
        importanceLevel: .normal,
        sourceType: .rss,
        isRead: true,
        entityId: "e2",
        replyToAddress: nil,
        linkURLString: "https://swift.org/blog/swift-6-2-released",
        contentHTML: "<p>The Swift team is pleased to announce <strong>Swift 6.2</strong>, featuring improved macros and new standard library additions.</p>"
    )
    let entity = Entity(
        displayName: "Swift.org Blog",
        protectionLevel: .normal,
        retentionPolicy: .keepLatest(20)
    )
    PostCardView(item: item, entity: entity)
        .padding()
        .modelContainer(for: Entity.self, inMemory: true)
}
