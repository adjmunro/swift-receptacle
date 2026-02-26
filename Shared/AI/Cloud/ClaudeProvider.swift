import Foundation

// MARK: - ClaudeProvider

/// Cloud AI backed by the Anthropic Claude API.
///
/// Opt-in only. API key stored in Keychain. All calls gated by AIPermissionManager.
/// Phase 8 implementation: integrate jamesrochabrun/SwiftAnthropic.
actor ClaudeProvider: AIProvider {
    let providerId = "claude"
    let displayName = "Anthropic Claude"
    let isLocal = false

    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func summarise(text: String) async throws -> String {
        // TODO Phase 8:
        // let anthropic = SwiftAnthropic(apiKey: apiKey)
        // let message = try await anthropic.createMessage(
        //     MessageParameter(model: .claude_sonnet_4_6, maxTokens: 1024,
        //         messages: [.init(role: .user, content: .text(
        //             "Summarise the following email in 2-3 sentences:\n\n\(text)"
        //         ))])
        // )
        // return message.content.first?.text ?? ""
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
