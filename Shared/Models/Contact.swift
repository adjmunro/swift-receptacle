import Foundation
import SwiftData

// MARK: - Supporting Types

enum ContactType: String, Codable, CaseIterable, Sendable {
    case person
    case organization
    case newsletter
    case transactional
    case automated
    case feed
}

enum SourceType: String, Codable, CaseIterable, Sendable {
    case email
    case rss
    case slack
    case teams
    case iMessage
    case matrix
    case xmpp
    case discord
    case webView
    case calendar
}

struct SourceIdentifier: Codable, Sendable, Hashable {
    /// Which integration this identifier belongs to (email, rss, slack, etc.)
    var type: SourceType
    /// The actual identifier: email address, feed URL string, Slack handle, etc.
    var value: String
}

// MARK: - Contact

/// Source-of-truth record for a real person or organisation.
///
/// Only `.person` and `.organization` contacts sync with CNContactStore.
/// Newsletters, receipts, feeds, and automated senders are Receptacle-internal only.
@Model
final class Contact {
    var id: UUID
    var displayName: String
    var type: ContactType
    /// Link to the system Contacts app — only set for .person / .organization
    var cnContactId: String?
    /// All identifiers across every integration (email addrs, feed URLs, handles…)
    var sourceIdentifiers: [SourceIdentifier]
    /// Per-service thread URLs for WebView-based IM (e.g. facebook.com/messages/t/…)
    /// Keyed by service identifier string ("facebook", "messenger", etc.)
    var webViewThreadURLStrings: [String: String]

    init(
        displayName: String,
        type: ContactType = .person,
        cnContactId: String? = nil,
        sourceIdentifiers: [SourceIdentifier] = [],
        webViewThreadURLStrings: [String: String] = [:]
    ) {
        self.id = UUID()
        self.displayName = displayName
        self.type = type
        self.cnContactId = cnContactId
        self.sourceIdentifiers = sourceIdentifiers
        self.webViewThreadURLStrings = webViewThreadURLStrings
    }
}

// MARK: - Source Usage

/// Tracks per-(entity, source) usage for tab ordering in PostFeedView.
@Model
final class SourceUsage {
    var id: UUID
    var entityId: String
    var sourceType: SourceType
    var viewCount: Int
    var lastViewedAt: Date
    /// Updated by sync or JS injection for WebView-based sources
    var currentUnreadCount: Int

    init(entityId: String, sourceType: SourceType) {
        self.id = UUID()
        self.entityId = entityId
        self.sourceType = sourceType
        self.viewCount = 0
        self.lastViewedAt = .distantPast
        self.currentUnreadCount = 0
    }
}
