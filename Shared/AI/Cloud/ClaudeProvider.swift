import Foundation
import SwiftAnthropic
import Receptacle  // AIProvider, AIProviderError, ReplyTone, CalendarEventDraft

// MARK: - ClaudeProvider

/// Cloud AI backed by the Anthropic Claude API (jamesrochabrun/SwiftAnthropic).
///
/// Opt-in only — API key stored in Keychain. All calls gated by `AIGate`.
/// Default model: `claude-sonnet-4-6` (best balance of speed and quality).
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
        let service = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)
        let param = MessageParameter(
            model: .other(model),
            messages: [
                .init(role: .user,
                      content: .text("Summarise the following content in 2-3 concise sentences:\n\n\(text)"))
            ],
            maxTokens: 512
        )
        let response = try await service.createMessage(param)
        return response.content.compactMap {
            if case .text(let t) = $0 { return t } else { return nil }
        }.joined()
    }

    public func reframe(text: String, tone: ReplyTone) async throws -> String {
        let service = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)
        let param = MessageParameter(
            model: .other(model),
            messages: [
                .init(role: .user,
                      content: .text(text))
            ],
            maxTokens: 1024,
            system: .text(
                "You are a writing assistant. Rewrite the email reply in a \(toneDescription(tone)) tone. "
                + "Preserve all key information and intent. Return only the rewritten reply."
            )
        )
        let response = try await service.createMessage(param)
        return response.content.compactMap {
            if case .text(let t) = $0 { return t } else { return nil }
        }.joined()
    }

    public func parseEvent(from text: String) async throws -> CalendarEventDraft {
        let service = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)
        let systemPrompt = """
            Extract event details from the text and return valid JSON only, with no commentary.
            Format: {"title":"...","start":"ISO8601","end":"ISO8601","location":"...","attendees":[],"allDay":false}
            If a field is unknown, omit it or use null.
            """
        let param = MessageParameter(
            model: .other(model),
            messages: [
                .init(role: .user,
                      content: .text(text))
            ],
            maxTokens: 256,
            system: .text(systemPrompt)
        )
        let response = try await service.createMessage(param)
        let jsonString = response.content.compactMap {
            if case .text(let t) = $0 { return t } else { return nil }
        }.joined()
        return try decodeEventDraft(from: jsonString)
    }

    public func suggestTags(for text: String) async throws -> [String] {
        let service = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)
        let param = MessageParameter(
            model: .other(model),
            messages: [
                .init(role: .user,
                      content: .text(text))
            ],
            maxTokens: 128,
            system: .text(
                "Suggest 3-5 relevant single-word or short-phrase tags for this content. "
                + "Return only a comma-separated list, nothing else."
            )
        )
        let response = try await service.createMessage(param)
        let raw = response.content.compactMap {
            if case .text(let t) = $0 { return t } else { return nil }
        }.joined()
        return raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
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

    private func decodeEventDraft(from jsonString: String) throws -> CalendarEventDraft {
        // Extract JSON from the response (may be wrapped in markdown code blocks)
        var cleaned = jsonString
        if let start = cleaned.range(of: "{"), let end = cleaned.range(of: "}", options: .backwards) {
            cleaned = String(cleaned[start.lowerBound...end.upperBound])
        }
        guard let data = cleaned.data(using: .utf8) else {
            throw AIProviderError.decodingFailed
        }

        struct ParsedEvent: Decodable {
            var title: String?
            var start: String?
            var end: String?
            var location: String?
            var attendees: [String]?
            var allDay: Bool?
        }

        let parsed = try JSONDecoder().decode(ParsedEvent.self, from: data)
        let iso = ISO8601DateFormatter()
        let startDate = parsed.start.flatMap { iso.date(from: $0) } ?? Date().addingTimeInterval(3600)
        let endDate = parsed.end.flatMap { iso.date(from: $0) } ?? startDate.addingTimeInterval(3600)

        return CalendarEventDraft(
            title: parsed.title ?? "Untitled Event",
            startDate: startDate,
            endDate: endDate,
            location: parsed.location,
            attendees: parsed.attendees ?? [],
            isAllDay: parsed.allDay ?? false
        )
    }
}
