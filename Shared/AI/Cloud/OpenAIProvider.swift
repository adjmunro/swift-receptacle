import Foundation
import OpenAI
import Receptacle  // AIProvider, AIProviderError, ReplyTone, CalendarEventDraft

// MARK: - OpenAIProvider

/// Cloud AI backed by the OpenAI API (MacPaw/OpenAI client).
///
/// Opt-in only — API key stored in Keychain. All calls gated by `AIGate`.
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
        let client = OpenAI(apiToken: apiKey)
        let query = ChatQuery(
            messages: [
                .system(.init(content: .textContent(
                    "You are an expert content summariser. Summarise in 2-3 concise sentences."))),
                .user(.init(content: .string(text)))
            ],
            model: model
        )
        let result = try await client.chats(query: query)
        return result.choices.first?.message.content ?? ""
    }

    public func reframe(text: String, tone: ReplyTone) async throws -> String {
        let client = OpenAI(apiToken: apiKey)
        let query = ChatQuery(
            messages: [
                .system(.init(content: .textContent(
                    "Rewrite this email reply in a \(toneDescription(tone)) tone. "
                    + "Preserve meaning and key points. Return only the rewritten text."))),
                .user(.init(content: .string(text)))
            ],
            model: model
        )
        let result = try await client.chats(query: query)
        return result.choices.first?.message.content ?? ""
    }

    public func parseEvent(from text: String) async throws -> CalendarEventDraft {
        let client = OpenAI(apiToken: apiKey)
        let query = ChatQuery(
            messages: [
                .system(.init(content: .textContent(
                    """
                    Extract event details from the text and return valid JSON only, no commentary.
                    Format: {"title":"...","start":"ISO8601","end":"ISO8601","location":"...","attendees":[],"allDay":false}
                    Omit unknown fields or use null.
                    """))),
                .user(.init(content: .string(text)))
            ],
            model: model
        )
        let result = try await client.chats(query: query)
        let jsonString = result.choices.first?.message.content ?? ""
        return try decodeEventDraft(from: jsonString)
    }

    public func suggestTags(for text: String) async throws -> [String] {
        let client = OpenAI(apiToken: apiKey)
        let query = ChatQuery(
            messages: [
                .system(.init(content: .textContent(
                    "Suggest 3-5 relevant single-word or short-phrase tags for this content. "
                    + "Return only a comma-separated list, nothing else."))),
                .user(.init(content: .string(text)))
            ],
            model: model
        )
        let result = try await client.chats(query: query)
        let raw = result.choices.first?.message.content ?? ""
        return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
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

    private func decodeEventDraft(from jsonString: String) throws -> CalendarEventDraft {
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
