import Foundation
import SwiftData
import Receptacle

// MARK: - Entity

/// What the inbox shows. Usually 1:1 with a Contact, but can represent a GROUP
/// of contacts that share rules (e.g. "All Work Test Accounts").
///
/// Enums used here (`ImportanceLevel`, `ProtectionLevel`, `RetentionPolicy`,
/// `ReplyTone`, `MatchType`, `ImportancePattern`, `AttachmentAction`, `SubRule`)
/// are defined in `ReceptacleCore/CoreTypes.swift` and imported via `Receptacle`.
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
    /// Desired refresh cadence for feed entities, in minutes. Stored so the sync
    /// scheduler can respect per-feed intervals. Default: 60 (hourly).
    var feedRefreshIntervalMinutes: Int = 60

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
