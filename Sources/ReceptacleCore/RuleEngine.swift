import Foundation

// MARK: - Value-type snapshots (decoupled from SwiftData for testability)

/// Lightweight snapshot of an item used by `RuleEngine`.
/// Populated from SwiftData models in the app; constructed directly in tests.
public struct ItemSnapshot: Sendable {
    public var id: String
    public var entityId: String
    public var date: Date
    public var subject: String?
    public var bodyPreview: String?
    public var headers: [String: String]
    public var attachmentFilenames: [String]
    public var importanceLevel: ImportanceLevel

    public init(
        id: String,
        entityId: String,
        date: Date,
        subject: String? = nil,
        bodyPreview: String? = nil,
        headers: [String: String] = [:],
        attachmentFilenames: [String] = [],
        importanceLevel: ImportanceLevel = .normal
    ) {
        self.id = id
        self.entityId = entityId
        self.date = date
        self.subject = subject
        self.bodyPreview = bodyPreview
        self.headers = headers
        self.attachmentFilenames = attachmentFilenames
        self.importanceLevel = importanceLevel
    }
}

/// Lightweight snapshot of an entity used by `RuleEngine`.
public struct EntitySnapshot: Sendable {
    public var id: String
    public var retentionPolicy: RetentionPolicy
    public var protectionLevel: ProtectionLevel
    public var importanceLevel: ImportanceLevel
    public var importancePatterns: [ImportancePattern]
    public var subRules: [SubRule]

    public init(
        id: String,
        retentionPolicy: RetentionPolicy,
        protectionLevel: ProtectionLevel = .normal,
        importanceLevel: ImportanceLevel = .normal,
        importancePatterns: [ImportancePattern] = [],
        subRules: [SubRule] = []
    ) {
        self.id = id
        self.retentionPolicy = retentionPolicy
        self.protectionLevel = protectionLevel
        self.importanceLevel = importanceLevel
        self.importancePatterns = importancePatterns
        self.subRules = subRules
    }
}

// MARK: - RuleEngine

/// Applies entity-level retention policies and sub-rules to a set of items.
/// Returns the set of item IDs that should be removed (archived or deleted).
///
/// Pure business logic — no SwiftData or networking. Fully unit-testable.
public struct RuleEngine: Sendable {

    public struct EvaluationResult: Sendable {
        public var itemsToDelete: [String]
        public var itemsToArchive: [String]
        public var attachmentsToSave: [(itemId: String, filename: String, action: AttachmentAction)]
        /// Items whose importance level was elevated by a matching `ImportancePattern`.
        /// Key = item id, value = the highest elevated `ImportanceLevel` from all matching patterns.
        /// Only contains entries for items that actually matched a pattern.
        public var elevatedImportance: [String: ImportanceLevel]

        public init(
            itemsToDelete: [String] = [],
            itemsToArchive: [String] = [],
            attachmentsToSave: [(itemId: String, filename: String, action: AttachmentAction)] = [],
            elevatedImportance: [String: ImportanceLevel] = [:]
        ) {
            self.itemsToDelete = itemsToDelete
            self.itemsToArchive = itemsToArchive
            self.attachmentsToSave = attachmentsToSave
            self.elevatedImportance = elevatedImportance
        }
    }

    public init() {}

    /// Evaluate retention rules for a slice of items belonging to one entity.
    ///
    /// - Parameters:
    ///   - items: All items currently stored for the entity (sorted newest first)
    ///   - entity: The entity whose rules apply
    ///   - now: Current date (injectable for testing)
    public func evaluate(
        items: [ItemSnapshot],
        entity: EntitySnapshot,
        now: Date = Date()
    ) -> EvaluationResult {
        var toDelete: [String] = []
        var toArchive: [String] = []
        var toSaveAttachments: [(String, String, AttachmentAction)] = []

        // --- Importance pattern elevation ---
        // For each item, find the highest-priority ImportancePattern that matches.
        // Only items that actually match a pattern get an entry in elevatedImportance.
        var elevatedImportance: [String: ImportanceLevel] = [:]
        for item in items {
            for pattern in entity.importancePatterns {
                guard matchesImportancePattern(item: item, pattern: pattern) else { continue }
                let current = elevatedImportance[item.id] ?? item.importanceLevel
                if pattern.elevatedLevel > current {
                    elevatedImportance[item.id] = pattern.elevatedLevel
                }
            }
        }

        // --- Retention policy application ---
        for item in items {
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
                    for filename in item.attachmentFilenames {
                        toSaveAttachments.append((item.id, filename, attachAction))
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

        // --- Protection level ---
        // .protected entities are shielded from all automatic deletion.
        // (Archiving is still permitted; deletion requires explicit user action in the UI.)
        if entity.protectionLevel == .protected {
            toDelete.removeAll()
        }

        return EvaluationResult(
            itemsToDelete: toDelete,
            itemsToArchive: toArchive,
            attachmentsToSave: toSaveAttachments,
            elevatedImportance: elevatedImportance
        )
    }

    // MARK: - Private

    private func matchesImportancePattern(item: ItemSnapshot, pattern: ImportancePattern) -> Bool {
        switch pattern.matchType {
        case .subjectContains:
            return item.subject?.localizedCaseInsensitiveContains(pattern.pattern) == true
        case .bodyContains:
            return item.bodyPreview?.localizedCaseInsensitiveContains(pattern.pattern) == true
        case .headerMatches:
            return item.headers[pattern.pattern] != nil
        }
    }

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
            break

        case .keepLatest(let n):
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
