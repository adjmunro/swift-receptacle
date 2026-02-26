/// Core value types for Receptacle — pure Swift, no SwiftData or SwiftUI macros.
/// These compile with swift CLI tools (no Xcode required).
///
/// The full SwiftData `@Model` versions live in Shared/Models/ and are used
/// exclusively by Xcode app targets (macOS + iOS).
import Foundation

// MARK: - Contact & Source types

public enum ContactType: String, Codable, CaseIterable, Sendable {
    case person
    case organization
    case newsletter
    case transactional
    case automated
    case feed
}

public enum SourceType: String, Codable, CaseIterable, Sendable {
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

public struct SourceIdentifier: Codable, Sendable, Hashable {
    public var type: SourceType
    public var value: String

    public init(type: SourceType, value: String) {
        self.type = type
        self.value = value
    }
}

// MARK: - Importance & Protection

public enum ImportanceLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case normal = 0
    case important = 1
    case critical = 2

    public static func < (lhs: ImportanceLevel, rhs: ImportanceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum ProtectionLevel: String, Codable, CaseIterable, Sendable {
    case protected
    case normal
    case apocalyptic
}

// MARK: - Retention & Rules

public enum RetentionPolicy: Codable, Sendable {
    case keepAll
    case keepLatest(Int)
    case keepDays(Int)
    case autoArchive
    case autoDelete

    public var displayName: String {
        switch self {
        case .keepAll: return "Keep all"
        case .keepLatest(let n): return "Keep latest \(n)"
        case .keepDays(let n): return "Keep \(n) days"
        case .autoArchive: return "Auto-archive"
        case .autoDelete: return "Auto-delete"
        }
    }
}

public enum ReplyTone: Codable, Sendable {
    case formal
    case casualClean
    case friendly
    case custom(prompt: String)

    public var displayName: String {
        switch self {
        case .formal: return "Formal"
        case .casualClean: return "Casual (clean)"
        case .friendly: return "Friendly"
        case .custom(let prompt): return "Custom: \(prompt.prefix(40))"
        }
    }
}

public enum MatchType: String, Codable, CaseIterable, Sendable {
    case subjectContains
    case bodyContains
    case headerMatches
}

public enum AttachmentSaveDestination: Codable, Sendable {
    case iCloudDrive(subfolder: String)
    case localFolder(bookmarkData: Data)
}

public struct AttachmentAction: Codable, Sendable {
    public var filenamePattern: String?
    public var mimeTypes: [String]
    public var saveDestination: AttachmentSaveDestination

    public init(
        filenamePattern: String? = nil,
        mimeTypes: [String] = [],
        saveDestination: AttachmentSaveDestination
    ) {
        self.filenamePattern = filenamePattern
        self.mimeTypes = mimeTypes
        self.saveDestination = saveDestination
    }
}

public struct SubRule: Codable, Sendable {
    public var matchType: MatchType
    public var pattern: String
    public var action: RetentionPolicy
    public var attachmentAction: AttachmentAction?

    public init(
        matchType: MatchType,
        pattern: String,
        action: RetentionPolicy,
        attachmentAction: AttachmentAction? = nil
    ) {
        self.matchType = matchType
        self.pattern = pattern
        self.action = action
        self.attachmentAction = attachmentAction
    }
}

public struct ImportancePattern: Codable, Sendable {
    public var matchType: MatchType
    public var pattern: String
    public var elevatedLevel: ImportanceLevel

    public init(matchType: MatchType, pattern: String, elevatedLevel: ImportanceLevel) {
        self.matchType = matchType
        self.pattern = pattern
        self.elevatedLevel = elevatedLevel
    }
}

// MARK: - AI types

public enum AIFeature: String, Codable, CaseIterable, Sendable {
    case summarise
    case reframeTone
    case transcribe
    case privacySummary
    case tagSuggest
    case eventParse

    public var displayName: String {
        switch self {
        case .summarise: return "Summarise"
        case .reframeTone: return "Reframe Tone"
        case .transcribe: return "Transcribe Voice"
        case .privacySummary: return "Privacy Policy Summary"
        case .tagSuggest: return "Suggest Tags"
        case .eventParse: return "Parse Events"
        }
    }
}

public enum AIScope: String, Codable, CaseIterable, Sendable {
    case always
    case askEachTime
    case never
}

/// Value-type AI permission record (mirrors the @Model AIPermission in Shared/).
public struct AIPermissionRecord: Codable, Sendable {
    public var providerId: String
    public var feature: AIFeature
    public var scope: AIScope
    public var entityId: String?

    public init(providerId: String, feature: AIFeature, scope: AIScope, entityId: String? = nil) {
        self.providerId = providerId
        self.feature = feature
        self.scope = scope
        self.entityId = entityId
    }
}
