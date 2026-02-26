import Foundation

// MARK: - AIProvider Protocol

/// Everything that can perform AI-assisted operations within Receptacle.
///
/// Local models (CoreML, WhisperKit) and cloud models (OpenAI, Claude) both conform.
/// All calls are gated through `AIPermissionManager` before reaching a provider.
protocol AIProvider: Sendable {
    var providerId: String { get }
    var displayName: String { get }
    var isLocal: Bool { get }

    /// Summarise a piece of text into a short paragraph
    func summarise(text: String) async throws -> String

    /// Rewrite text to match the given tone
    func reframe(text: String, tone: ReplyTone) async throws -> String

    /// Parse natural-language event description into structured data
    func parseEvent(from text: String) async throws -> CalendarEventDraft

    /// Suggest tag names for a piece of content
    func suggestTags(for text: String) async throws -> [String]
}

// MARK: - AIProviderError

enum AIProviderError: Error, Sendable {
    case notConfigured
    case rateLimited
    case permissionDenied
    case networkError(reason: String)
    case modelUnavailable(modelId: String)
    case responseInvalid
}
