import Foundation
import SwiftData

// MARK: - Attachment

struct Attachment: Codable, Sendable, Identifiable {
    var id: UUID
    var filename: String
    var mimeType: String
    /// Size in bytes
    var size: Int
    /// Local file URL (after download) — stored as bookmark data for sandbox compatibility
    var localBookmarkData: Data?

    init(filename: String, mimeType: String, size: Int) {
        self.id = UUID()
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
    }
}

// MARK: - EmailItem

/// A single email message stored locally.
///
/// Conforms to the `Item` protocol so it can flow through the unified inbox.
@Model
final class EmailItem {
    /// Stable string identifier (IMAP UID + mailbox + account composite key)
    var id: String
    var entityId: String
    var sourceId: String
    var date: Date

    var subject: String
    var fromAddress: String
    var fromName: String?
    var toAddresses: [String]
    var ccAddresses: [String]
    var replyToAddress: String?

    /// Full HTML body — rendered via native WebView
    var bodyHTML: String?
    /// Plain-text fallback
    var bodyPlain: String?
    /// Character ranges in bodyPlain that represent quoted/forwarded content
    var quotedRangeLocations: [Int]
    var quotedRangeLengths: [Int]

    var attachments: [Attachment]

    var isRead: Bool
    var isArchived: Bool
    var isDeleted: Bool
    var isFlagged: Bool

    /// AI-generated one-sentence summary (cached after first generation)
    var aiSummary: String?

    var tagIds: [String]

    init(
        id: String,
        entityId: String,
        sourceId: String,
        date: Date,
        subject: String,
        fromAddress: String,
        fromName: String? = nil,
        toAddresses: [String] = [],
        ccAddresses: [String] = [],
        replyToAddress: String? = nil,
        bodyHTML: String? = nil,
        bodyPlain: String? = nil
    ) {
        self.id = id
        self.entityId = entityId
        self.sourceId = sourceId
        self.date = date
        self.subject = subject
        self.fromAddress = fromAddress
        self.fromName = fromName
        self.toAddresses = toAddresses
        self.ccAddresses = ccAddresses
        self.replyToAddress = replyToAddress
        self.bodyHTML = bodyHTML
        self.bodyPlain = bodyPlain
        self.quotedRangeLocations = []
        self.quotedRangeLengths = []
        self.attachments = []
        self.isRead = false
        self.isArchived = false
        self.isDeleted = false
        self.isFlagged = false
        self.tagIds = []
    }

    /// Plain-text preview for list row (first ~150 chars of body, stripped of HTML tags)
    var summary: String {
        if let plain = bodyPlain, !plain.isEmpty {
            return String(plain.prefix(150))
        }
        // Very naive HTML strip for preview only — full render uses WebView
        if let html = bodyHTML {
            let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            return String(stripped.prefix(150))
        }
        return subject
    }

    /// Address to use for replies: Reply-To if present, otherwise From
    var effectiveReplyToAddress: String {
        replyToAddress ?? fromAddress
    }
}

extension EmailItem: Item {
    // Explicit conformance provided by the stored properties above
}
