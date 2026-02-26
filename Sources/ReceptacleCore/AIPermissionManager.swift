import Foundation

// MARK: - AIPermissionManager

/// Central gate for all AI operations.
///
/// Uses value-type `AIPermissionRecord` (not the SwiftData `@Model AIPermission`).
/// The app layer populates this from SwiftData on startup.
///
/// Resolution order (highest to lowest precedence):
///   1. Per-entity record for (providerId, feature, entityId)
///   2. Global default for (providerId, feature) — entityId == nil
///   3. Fall back to `.askEachTime`
public actor AIPermissionManager {

    private var permissions: [String: AIPermissionRecord] = [:]

    public init(permissions: [AIPermissionRecord] = []) {
        for p in permissions {
            let key = "\(p.providerId):\(p.feature.rawValue):\(p.entityId ?? "*")"
            self.permissions[key] = p
        }
    }

    public func load(permissions: [AIPermissionRecord]) {
        self.permissions = [:]
        for p in permissions {
            let key = "\(p.providerId):\(p.feature.rawValue):\(p.entityId ?? "*")"
            self.permissions[key] = p
        }
    }

    public func scope(
        for providerId: String,
        feature: AIFeature,
        entityId: String? = nil
    ) -> AIScope {
        if let entityId {
            let key = cacheKey(providerId: providerId, feature: feature, entityId: entityId)
            if let p = permissions[key] { return p.scope }
        }
        let globalKey = cacheKey(providerId: providerId, feature: feature, entityId: nil)
        return permissions[globalKey]?.scope ?? .askEachTime
    }

    public func isAllowed(providerId: String, feature: AIFeature, entityId: String? = nil) -> Bool {
        scope(for: providerId, feature: feature, entityId: entityId) == .always
    }

    public func isDenied(providerId: String, feature: AIFeature, entityId: String? = nil) -> Bool {
        scope(for: providerId, feature: feature, entityId: entityId) == .never
    }

    @discardableResult
    public func set(
        scope: AIScope,
        providerId: String,
        feature: AIFeature,
        entityId: String? = nil
    ) -> AIPermissionRecord {
        let key = cacheKey(providerId: providerId, feature: feature, entityId: entityId)
        let record = AIPermissionRecord(
            providerId: providerId,
            feature: feature,
            scope: scope,
            entityId: entityId
        )
        permissions[key] = record
        return record
    }

    // MARK: - Private

    private func cacheKey(providerId: String, feature: AIFeature, entityId: String?) -> String {
        "\(providerId):\(feature.rawValue):\(entityId ?? "*")"
    }
}
