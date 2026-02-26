import Foundation
import Receptacle  // AIProvider, AIProviderError, ReplyTone, CalendarEventDraft

// MARK: - ClaudeProvider

/// Cloud AI backed by the Anthropic Claude API (jamesrochabrun/SwiftAnthropic).
///
/// Opt-in only — API key stored in Keychain. All calls gated by `AIGate`.
/// Default model: `claude-sonnet-4-6` (best balance of speed and quality).
///
/// ## SwiftAnthropic integration (requires Xcode + package linked):
///
/// ### Summarise:
/// ```swift
/// let anthropic = AnthropicSwiftUI(apiKey: apiKey)
/// // or: let anthropic = Anthropic(apiKey: apiKey)
/// let param = MessageParameter(
///     model: .claude_sonnet_4_6,    // "claude-sonnet-4-6"
///     messages: [
///         .init(role: .user, content: .list([
///             .text("Summarise the following email in 2-3 sentences:\n\n\(text)")
///         ]))
///     ],
///     maxTokens: 512
/// )
/// let response = try await anthropic.createMessage(param)
/// return response.content.compactMap { block -> String? in
///     if case .text(let t) = block { return t.text }
///     return nil
/// }.joined()
/// ```
///
/// ### Reframe tone:
/// ```swift
/// let systemPrompt = "You are a writing assistant. " +
///     "Rewrite the user's email reply in a \(toneDescription(tone)) tone. " +
///     "Preserve meaning. Return only the rewritten text, no commentary."
/// let param = MessageParameter(
///     model: .claude_sonnet_4_6,
///     system: systemPrompt,
///     messages: [.init(role: .user, content: .list([.text(text)]))],
///     maxTokens: 1024
/// )
/// ```
///
/// ### Event parsing (Phase 12):
/// ```swift
/// let systemPrompt = """
///     Extract event details from the text as JSON:
///     {"title":"...","start":"ISO8601","end":"ISO8601","location":"...","attendees":[]}
///     Return only valid JSON.
///     """
/// let param = MessageParameter(
///     model: .claude_sonnet_4_6,
///     system: systemPrompt,
///     messages: [.init(role: .user, content: .list([.text(text)]))],
///     maxTokens: 256
/// )
/// // Then decode with JSONDecoder
/// ```
public actor ClaudeProvider: AIProvider {

    public let providerId   = "claude"
    public let displayName  = "Anthropic Claude"
    public let isLocal      = false

    private let apiKey: String
    /// Default model. Update when newer Claude models ship.
    public var model: String = "claude-sonnet-4-6"

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - AIProvider

    public func summarise(text: String) async throws -> String {
        // Uncomment when SwiftAnthropic is linked in Xcode target:
        //
        // let anthropic = Anthropic(apiKey: apiKey)
        // let param = MessageParameter(
        //     model: .init(model),
        //     messages: [.init(role: .user, content: .list([
        //         .text("Summarise the following email in 2-3 sentences:\n\n\(text)")
        //     ]))],
        //     maxTokens: 512
        // )
        // let response = try await anthropic.createMessage(param)
        // return response.content.compactMap { block -> String? in
        //     if case .text(let t) = block { return t.text }
        //     return nil
        // }.joined()
        throw AIProviderError.notConfigured
    }

    public func reframe(text: String, tone: ReplyTone) async throws -> String {
        // Uncomment when SwiftAnthropic is linked (Phase 9):
        //
        // let systemPrompt = "You are a writing assistant. "
        //     + "Rewrite the email reply in a \(toneDescription(tone)) tone. "
        //     + "Preserve all key information. Return only the rewritten reply."
        // let anthropic = Anthropic(apiKey: apiKey)
        // let param = MessageParameter(
        //     model: .init(model),
        //     system: systemPrompt,
        //     messages: [.init(role: .user, content: .list([.text(text)]))],
        //     maxTokens: 1024
        // )
        // let response = try await anthropic.createMessage(param)
        // return response.content.compactMap { block -> String? in
        //     if case .text(let t) = block { return t.text }
        //     return nil
        // }.joined()
        throw AIProviderError.notConfigured
    }

    public func parseEvent(from text: String) async throws -> CalendarEventDraft {
        // Phase 12: structured JSON output + JSONDecoder
        throw AIProviderError.notConfigured
    }

    public func suggestTags(for text: String) async throws -> [String] {
        // Phase 10
        throw AIProviderError.notConfigured
    }

    // MARK: - Helpers

    public static func apiKey(from keychain: Void = ()) -> String? {
        try? KeychainHelper.read(account: "anthropic.apikey")
    }

    private func toneDescription(_ tone: ReplyTone) -> String {
        switch tone {
        case .formal:           return "formal and professional"
        case .casualClean:      return "casual but polished"
        case .friendly:         return "warm and friendly"
        case .custom(let p):    return p
        }
    }
}
