import Foundation

// MARK: - AIPermissionManager

/// Central gate for all AI operations.
///
/// Before any `AIProvider` method is called, the caller MUST check here.
/// `AIPermission` records are read from SwiftData (loaded on init or injected for testing).
///
/// Resolution order:
///   1. Per-entity permission for this (providerId, feature, entityId)
///   2. Global default for this (providerId, feature) — entityId == nil
///   3. If no record: default to `.askEachTime`
actor AIPermissionManager {
    private var permissions: [String: AIPermission] = [:]

    init(permissions: [AIPermission] = []) {
        for p in permissions {
            let key = cacheKey(providerId: p.providerId, feature: p.feature, entityId: p.entityId)
            self.permissions[key] = p
        }
    }

    /// Load permissions from SwiftData (called on first use if not injected)
    func load(permissions: [AIPermission]) {
        self.permissions = [:]
        for p in permissions {
            let key = cacheKey(providerId: p.providerId, feature: p.feature, entityId: p.entityId)
            self.permissions[key] = p
        }
    }

    /// Returns the effective scope for a given provider + feature + entity combination.
    func scope(
        for providerId: String,
        feature: AIFeature,
        entityId: String? = nil
    ) -> AIScope {
        // Per-entity override
        if let entityId {
            let key = cacheKey(providerId: providerId, feature: feature, entityId: entityId)
            if let p = permissions[key] { return p.scope }
        }
        // Global default
        let globalKey = cacheKey(providerId: providerId, feature: feature, entityId: nil)
        return permissions[globalKey]?.scope ?? .askEachTime
    }

    /// Returns true if this operation is permitted to proceed without asking.
    func isAllowed(providerId: String, feature: AIFeature, entityId: String? = nil) -> Bool {
        scope(for: providerId, feature: feature, entityId: entityId) == .always
    }

    /// Returns true if this operation is explicitly blocked.
    func isDenied(providerId: String, feature: AIFeature, entityId: String? = nil) -> Bool {
        scope(for: providerId, feature: feature, entityId: entityId) == .never
    }

    /// Persist a permission decision. Caller is responsible for saving to SwiftData.
    func set(
        scope: AIScope,
        providerId: String,
        feature: AIFeature,
        entityId: String? = nil
    ) -> AIPermission {
        let key = cacheKey(providerId: providerId, feature: feature, entityId: entityId)
        let existing = permissions[key]
        let permission = existing ?? AIPermission(
            providerId: providerId,
            feature: feature,
            scope: scope,
            entityId: entityId
        )
        if existing != nil {
            permission.scope = scope
        }
        permissions[key] = permission
        return permission
    }

    // MARK: - Private

    private func cacheKey(providerId: String, feature: AIFeature, entityId: String?) -> String {
        "\(providerId):\(feature.rawValue):\(entityId ?? "*")"
    }
}
