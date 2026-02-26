import Foundation

// MARK: - CalendarEventParser

/// AI-gated natural-language → `CalendarEventDraft` parser.
///
/// Wraps `AIProvider.parseEvent(from:)` through `AIGate` with the `.eventParse` feature.
/// The result is a `CalendarEventDraft` ready for user confirmation before writing to EventKit.
///
/// Usage:
/// ```swift
/// let parser = CalendarEventParser(
///     aiProvider: localWhisper,
///     gate: AIGate.shared,
///     providerId: "local-whisper"
/// )
/// let draft = try await parser.parse(text: "Lunch with Alice tomorrow noon at The Office")
/// // Present draft in CalendarEventCreatorView for user confirmation.
/// ```
public actor CalendarEventParser {

    private let aiProvider: any AIProvider
    private let gate: AIGate
    private let providerId: String

    public init(aiProvider: any AIProvider, gate: AIGate, providerId: String) {
        self.aiProvider = aiProvider
        self.gate = gate
        self.providerId = providerId
    }

    /// Parse natural-language text into a `CalendarEventDraft`.
    ///
    /// - Parameters:
    ///   - text: Free-form description of the event (typed or voice-transcribed).
    ///   - entityId: Optional entity context for per-sender permission overrides.
    /// - Returns: A `CalendarEventDraft` populated by the AI model.
    /// - Throws: `AIProviderError.permissionDenied` if the `.eventParse` scope is `.never`.
    public func parse(text: String, entityId: String? = nil) async throws -> CalendarEventDraft {
        let provider = aiProvider
        return try await gate.perform(
            providerId: providerId,
            feature: .eventParse,
            entityId: entityId
        ) {
            try await provider.parseEvent(from: text)
        }
    }
}
