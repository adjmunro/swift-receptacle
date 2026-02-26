import Foundation
import SwiftData
import Receptacle

// MARK: - AIPermission

/// Persists the user's consent decision for a given AI provider + feature + entity scope.
///
/// `entityId == nil` means this is the global default for that provider+feature pair.
/// A per-entity record takes precedence over the global default.
///
/// `AIFeature` and `AIScope` enums are defined in `ReceptacleCore/CoreTypes.swift`
/// and imported via `Receptacle`.
@Model
final class AIPermission {
    var id: UUID
    /// Identifies the AI backend: "local-whisper", "openai", "claude", etc.
    var providerId: String
    var feature: AIFeature
    var scope: AIScope
    /// `nil` = global default; non-nil = per-entity override
    var entityId: String?

    init(
        providerId: String,
        feature: AIFeature,
        scope: AIScope,
        entityId: String? = nil
    ) {
        self.id = UUID()
        self.providerId = providerId
        self.feature = feature
        self.scope = scope
        self.entityId = entityId
    }
}
