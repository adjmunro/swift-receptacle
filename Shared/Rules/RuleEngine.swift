import Foundation

// MARK: - RuleEngine

/// Applies entity-level retention policies and sub-rules to a set of items,
/// returning the set of item IDs that should be removed (archived or deleted).
///
/// This is pure business logic — no SwiftData or networking. Fully unit-testable.
///
/// See Phase 1 for full TDD implementation.
struct RuleEngine {

    // MARK: - Public API

    struct EvaluationResult {
        var itemsToDelete: [String]
        var itemsToArchive: [String]
        var attachmentsToSave: [(itemId: String, attachment: String, action: AttachmentAction)]
    }

    /// Evaluate retention rules for a slice of items belonging to one entity.
    ///
    /// - Parameters:
    ///   - items: All items currently stored for the entity (sorted newest first)
    ///   - entity: The entity whose rules apply
    ///   - now: Current date (injectable for testing)
    /// - Returns: Which items should be deleted/archived and which attachments to save
    func evaluate(
        items: [ItemSnapshot],
        entity: EntitySnapshot,
        now: Date = Date()
    ) -> EvaluationResult {
        var toDelete: [String] = []
        var toArchive: [String] = []
        var toSaveAttachments: [(String, String, AttachmentAction)] = []

        for item in items {
            // Sub-rules take precedence over the entity-level policy
            if let matchedSubRule = entity.subRules.first(where: { matches(item: item, rule: $0) }) {
                apply(
                    policy: matchedSubRule.action,
                    to: item,
                    items: items,
                    now: now,
                    toDelete: &toDelete,
                    toArchive: &toArchive
                )
                if let attachAction = matchedSubRule.attachmentAction {
                    for attachment in item.attachmentFilenames {
                        toSaveAttachments.append((item.id, attachment, attachAction))
                    }
                }
            } else {
                apply(
                    policy: entity.retentionPolicy,
                    to: item,
                    items: items,
                    now: now,
                    toDelete: &toDelete,
                    toArchive: &toArchive
                )
            }
        }

        return EvaluationResult(
            itemsToDelete: toDelete,
            itemsToArchive: toArchive,
            attachmentsToSave: toSaveAttachments
        )
    }

    // MARK: - Private Helpers

    private func matches(item: ItemSnapshot, rule: SubRule) -> Bool {
        switch rule.matchType {
        case .subjectContains:
            return item.subject?.localizedCaseInsensitiveContains(rule.pattern) == true
        case .bodyContains:
            return item.bodyPreview?.localizedCaseInsensitiveContains(rule.pattern) == true
        case .headerMatches:
            return item.headers[rule.pattern] != nil
        }
    }

    private func apply(
        policy: RetentionPolicy,
        to item: ItemSnapshot,
        items: [ItemSnapshot],
        now: Date,
        toDelete: inout [String],
        toArchive: inout [String]
    ) {
        switch policy {
        case .keepAll:
            break   // No action

        case .keepLatest(let n):
            // items is sorted newest first; keep the first n
            let rank = items.firstIndex(where: { $0.id == item.id }) ?? 0
            if rank >= n {
                toDelete.append(item.id)
            }

        case .keepDays(let days):
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now)!
            if item.date < cutoff {
                toDelete.append(item.id)
            }

        case .autoArchive:
            toArchive.append(item.id)

        case .autoDelete:
            toDelete.append(item.id)
        }
    }
}

// MARK: - Value-type snapshots (decoupled from SwiftData for testability)

/// A lightweight snapshot of an item used by `RuleEngine`.
/// Populated from SwiftData models but carries no managed-object references.
struct ItemSnapshot: Sendable {
    var id: String
    var entityId: String
    var date: Date
    var subject: String?
    var bodyPreview: String?
    var headers: [String: String]
    var attachmentFilenames: [String]
    var importanceLevel: ImportanceLevel
}

/// A lightweight snapshot of an entity used by `RuleEngine`.
struct EntitySnapshot: Sendable {
    var id: String
    var retentionPolicy: RetentionPolicy
    var protectionLevel: ProtectionLevel
    var importanceLevel: ImportanceLevel
    var importancePatterns: [ImportancePattern]
    var subRules: [SubRule]
}
