// MARK: - AIGate

/// Enforces AI permission rules before dispatching any AI operation.
///
/// Every call to a concrete `AIProvider` must go through `AIGate.perform()`.
/// The gate checks `AIPermissionManager` and throws `permissionDenied` when
/// the effective scope is `.never`.
///
/// Scope semantics:
/// | Scope         | Gate behaviour                                              |
/// |---------------|-------------------------------------------------------------|
/// | `.always`     | Proceeds immediately                                        |
/// | `.askEachTime`| Proceeds (caller is responsible for showing a confirmation  |
/// |               | UI before invoking the gate)                                |
/// | `.never`      | Throws `AIProviderError.permissionDenied`                   |
///
/// Entity-level scope overrides the global scope — use `entityId` when the
/// call is associated with a specific sender.
///
/// Usage:
/// ```swift
/// let gate = AIGate(permissionManager: .shared)
///
/// // Gated summarise call
/// let summary = try await gate.perform(
///     providerId: "claude",
///     feature: .summarise,
///     entityId: entity.id
/// ) {
///     try await claudeProvider.summarise(text: emailBody)
/// }
/// ```
public actor AIGate {

    private let permissionManager: AIPermissionManager

    public init(permissionManager: AIPermissionManager = AIPermissionManager()) {
        self.permissionManager = permissionManager
    }

    // MARK: - Permission-gated dispatch

    /// Executes `operation` only if the effective permission scope allows it.
    ///
    /// - Parameters:
    ///   - providerId: The AI provider ID (e.g. `"openai"`, `"claude"`).
    ///   - feature:    The AI feature being used.
    ///   - entityId:   Optional entity-level scope override.
    ///   - operation:  The AI call to perform if permitted.
    /// - Returns:      The result of `operation`.
    /// - Throws:       `AIProviderError.permissionDenied` if scope is `.never`.
    public func perform<T: Sendable>(
        providerId: String,
        feature: AIFeature,
        entityId: String? = nil,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let scope = await permissionManager.scope(
            for: providerId,
            feature: feature,
            entityId: entityId
        )
        guard scope != .never else {
            throw AIProviderError.permissionDenied
        }
        return try await operation()
    }

    // MARK: - Convenience predicates

    /// Returns `true` if the feature is explicitly allowed (`.always`).
    public func isAlwaysAllowed(providerId: String,
                                feature: AIFeature,
                                entityId: String? = nil) async -> Bool {
        await permissionManager.scope(for: providerId, feature: feature, entityId: entityId) == .always
    }

    /// Returns `true` if the feature is explicitly blocked (`.never`).
    public func isBlocked(providerId: String,
                          feature: AIFeature,
                          entityId: String? = nil) async -> Bool {
        await permissionManager.scope(for: providerId, feature: feature, entityId: entityId) == .never
    }

    /// Returns `true` if the feature requires per-call confirmation.
    public func requiresConfirmation(providerId: String,
                                     feature: AIFeature,
                                     entityId: String? = nil) async -> Bool {
        await permissionManager.scope(for: providerId, feature: feature, entityId: entityId) == .askEachTime
    }

    // MARK: - Shared accessor

    public static let shared = AIGate(permissionManager: AIPermissionManager())
}
