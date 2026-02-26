import Foundation

// MARK: - OpenAIProvider

/// Cloud AI backed by the OpenAI API.
///
/// Opt-in only. API key stored in Keychain. All calls gated by AIPermissionManager.
/// Phase 8 implementation: integrate MacPaw/OpenAI client.
actor OpenAIProvider: AIProvider {
    let providerId = "openai"
    let displayName = "OpenAI (ChatGPT)"
    let isLocal = false

    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func summarise(text: String) async throws -> String {
        // TODO Phase 8:
        // let client = OpenAI(apiToken: apiKey)
        // let query = ChatQuery(model: .gpt4o, messages: [
        //     .init(role: .system, content: "Summarise the following in 2-3 sentences."),
        //     .init(role: .user, content: text)
        // ])
        // let result = try await client.chats(query: query)
        // return result.choices.first?.message.content ?? ""
        throw AIProviderError.notConfigured
    }

    func reframe(text: String, tone: ReplyTone) async throws -> String {
        // TODO Phase 8/9
        throw AIProviderError.notConfigured
    }

    func parseEvent(from text: String) async throws -> CalendarEventDraft {
        // TODO Phase 12
        throw AIProviderError.notConfigured
    }

    func suggestTags(for text: String) async throws -> [String] {
        // TODO Phase 10
        throw AIProviderError.notConfigured
    }
}
