import Foundation
import Receptacle  // AIProvider, AIProviderError, ReplyTone, CalendarEventDraft

// MARK: - OpenAIProvider

/// Cloud AI backed by the OpenAI API (MacPaw/OpenAI client).
///
/// Opt-in only — API key stored in Keychain. All calls gated by `AIGate`.
///
/// ## MacPaw/OpenAI integration (requires Xcode + package linked):
///
/// ### Summarise:
/// ```swift
/// let client = OpenAI(apiToken: apiKey)
/// let query = ChatQuery(
///     messages: [
///         .init(role: .system, content:
///             "You are an expert email summariser. Summarise in 2-3 concise sentences."),
///         .init(role: .user, content: text)
///     ],
///     model: .gpt4_o_mini    // cost-effective default; upgrade to .gpt4_o for quality
/// )
/// let result = try await client.chats(query: query)
/// return result.choices.first?.message.content?.string ?? ""
/// ```
///
/// ### Reframe tone:
/// ```swift
/// let toneInstruction: String
/// switch tone {
/// case .formal:       toneInstruction = "formal and professional"
/// case .casualClean:  toneInstruction = "casual but polished"
/// case .friendly:     toneInstruction = "warm and friendly"
/// case .custom(let p): toneInstruction = p
/// }
/// let query = ChatQuery(
///     messages: [
///         .init(role: .system, content:
///             "Rewrite the following email reply in a \(toneInstruction) tone. "
///             + "Preserve the meaning and key points."),
///         .init(role: .user, content: text)
///     ],
///     model: .gpt4_o_mini
/// )
/// ```
///
/// ### Tag suggestion:
/// ```swift
/// let query = ChatQuery(
///     messages: [
///         .init(role: .system, content:
///             "Suggest 3-5 relevant single-word or short-phrase tags for this content. "
///             + "Return only a comma-separated list, nothing else."),
///         .init(role: .user, content: text)
///     ],
///     model: .gpt4_o_mini
/// )
/// let raw = result.choices.first?.message.content?.string ?? ""
/// return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
/// ```
public actor OpenAIProvider: AIProvider {

    public let providerId   = "openai"
    public let displayName  = "OpenAI (ChatGPT)"
    public let isLocal      = false

    private let apiKey: String
    /// Default model. Can be overridden for cost/quality trade-offs.
    public var model: String = "gpt-4o-mini"

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - AIProvider

    public func summarise(text: String) async throws -> String {
        // Uncomment when MacPaw/OpenAI is linked in Xcode target:
        //
        // let client = OpenAI(apiToken: apiKey)
        // let query = ChatQuery(
        //     messages: [
        //         .init(role: .system, content:
        //             "Summarise the following email in 2-3 sentences. Be concise and factual."),
        //         .init(role: .user, content: text)
        //     ],
        //     model: .init(model)
        // )
        // let result = try await client.chats(query: query)
        // return result.choices.first?.message.content?.string ?? ""
        throw AIProviderError.notConfigured
    }

    public func reframe(text: String, tone: ReplyTone) async throws -> String {
        // Uncomment when MacPaw/OpenAI is linked:
        //
        // let toneInstruction = toneDescription(tone)
        // let client = OpenAI(apiToken: apiKey)
        // let query = ChatQuery(
        //     messages: [
        //         .init(role: .system, content:
        //             "Rewrite this email reply in a \(toneInstruction) tone. "
        //             + "Preserve meaning and key points. Return only the rewritten text."),
        //         .init(role: .user, content: text)
        //     ],
        //     model: .init(model)
        // )
        // let result = try await client.chats(query: query)
        // return result.choices.first?.message.content?.string ?? ""
        throw AIProviderError.notConfigured
    }

    public func parseEvent(from text: String) async throws -> CalendarEventDraft {
        // Uncomment when MacPaw/OpenAI is linked (Phase 12):
        //
        // Parse JSON response from structured output prompt:
        // { "title": "...", "start": "ISO8601", "end": "ISO8601", "location": "...", "attendees": [] }
        throw AIProviderError.notConfigured
    }

    public func suggestTags(for text: String) async throws -> [String] {
        // Uncomment when MacPaw/OpenAI is linked (Phase 10):
        throw AIProviderError.notConfigured
    }

    // MARK: - Helpers

    public static func apiKey(from keychain: Void = ()) -> String? {
        try? KeychainHelper.read(account: "openai.apikey")
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
