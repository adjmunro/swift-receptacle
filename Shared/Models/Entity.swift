import Foundation
import SwiftData

// MARK: - Enums

enum ImportanceLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case normal = 0
    case important = 1
    case critical = 2

    public static func < (lhs: ImportanceLevel, rhs: ImportanceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum ProtectionLevel: String, Codable, CaseIterable, Sendable {
    /// Never show destructive actions; require explicit confirmation for everything
    case protected
    /// Standard behaviour
    case normal
    /// Items are ephemeral; show "Delete All" swipe action
    case apocalyptic
}

enum RetentionPolicy: Codable, Sendable {
    case keepAll
    case keepLatest(Int)
    case keepDays(Int)
    case autoArchive
    case autoDelete
}

enum ReplyTone: Codable, Sendable {
    case formal
    case casualClean
    case friendly
    case custom(prompt: String)
}

enum MatchType: String, Codable, CaseIterable, Sendable {
    case subjectContains
    case bodyContains
    case headerMatches
}

// MARK: - Sub-models (value types, stored as Codable in SwiftData)

struct ImportancePattern: Codable, Sendable {
    var matchType: MatchType
    var pattern: String
    var elevatedLevel: ImportanceLevel
}

enum AttachmentSaveDestination: Codable, Sendable {
    case iCloudDrive(subfolder: String)
    case localFolder(bookmarkData: Data)
}

struct AttachmentAction: Codable, Sendable {
    var filenamePattern: String?
    var mimeTypes: [String]
    var saveDestination: AttachmentSaveDestination
}

struct SubRule: Codable, Sendable {
    var matchType: MatchType
    var pattern: String
    var action: RetentionPolicy
    var attachmentAction: AttachmentAction?
}

// MARK: - Entity

/// What the inbox shows. Usually 1:1 with a Contact, but can represent a GROUP
/// of contacts that share rules (e.g. "All Work Test Accounts").
@Model
final class Entity {
    var id: UUID
    var displayName: String
    /// The contacts that belong to this entity (one-to-many)
    var contactIds: [String]
    var importanceLevel: ImportanceLevel
    /// Per-item override patterns — if matched, item is elevated above entity default
    var importancePatterns: [ImportancePattern]
    var protectionLevel: ProtectionLevel
    var retentionPolicy: RetentionPolicy
    var replyTone: ReplyTone
    var subRules: [SubRule]

    init(
        displayName: String,
        contactIds: [String] = [],
        importanceLevel: ImportanceLevel = .normal,
        importancePatterns: [ImportancePattern] = [],
        protectionLevel: ProtectionLevel = .normal,
        retentionPolicy: RetentionPolicy = .keepAll,
        replyTone: ReplyTone = .formal,
        subRules: [SubRule] = []
    ) {
        self.id = UUID()
        self.displayName = displayName
        self.contactIds = contactIds
        self.importanceLevel = importanceLevel
        self.importancePatterns = importancePatterns
        self.protectionLevel = protectionLevel
        self.retentionPolicy = retentionPolicy
        self.replyTone = replyTone
        self.subRules = subRules
    }
}
